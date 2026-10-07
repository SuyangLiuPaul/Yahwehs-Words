import Foundation

struct CompanionPublicationPolicy {
  static func needsImmediateContext(_ data: [String: Any], after previous: [String: Any]) -> Bool {
    let keys = ["id", "title", "subtitle", "artwork", "locale", "reading", "daily", "duration", "loading", "canSkip", "canNext", "canPrevious", "playing", "error", "sermon", "queueIndex", "queueCount", "queueLabel", "shuffled", "repeat", "accent", "logo"]
    let identity = NSDictionary(dictionary: data.filter { keys.contains($0.key) })
    let old = NSDictionary(dictionary: previous.filter { keys.contains($0.key) })
    if !identity.isEqual(old) { return true }
    // A seek changes neither title nor playing. Do not leave a watch
    // projecting the old position until the next background transfer.
    let elapsed = max(0, ((data["syncedAt"] as? NSNumber)?.doubleValue ?? 0) -
      ((previous["syncedAt"] as? NSNumber)?.doubleValue ?? 0)) / 1000
    let advancing = previous["playing"] as? Bool == true && previous["loading"] as? Bool != true
    let expected = ((previous["position"] as? NSNumber)?.doubleValue ?? 0) + (advancing ? elapsed : 0)
    return abs(((data["position"] as? NSNumber)?.doubleValue ?? 0) - expected) > 2
  }
}

#if !MEDIA_COMPANION_LOGIC_TEST
import Flutter
import WatchConnectivity

/// One bridge per Flutter engine. Watch requests are allowlisted commands
/// against the phone's existing media session, never arbitrary URLs.
final class WordsMediaCompanion: NSObject, FlutterPlugin, WCSessionDelegate {
  static let shared = WordsMediaCompanion()
  private(set) var channel: FlutterMethodChannel?
  private var ready = false
  private var latest: [String: Any] = [:]
  static let stateChanged = Notification.Name("WordsMediaStateChanged")
  var snapshot: [String: Any] { latest }
  var locale: String { latest["locale"] as? String ?? "en" }
  private var sentContext: [String: Any] = [:]
  private var liveTransferPending = false
  private var liveTransferGeneration = 0
  private var lastTransfer = Date.distantPast

  static func register(with registrar: FlutterPluginRegistrar) {
    let bridge = shared
    let channel = FlutterMethodChannel(name: "yswords/media_companion",
                                       binaryMessenger: registrar.messenger())
    bridge.ready = false
    bridge.channel = channel
    registrar.addMethodCallDelegate(bridge, channel: channel)
    if WCSession.isSupported() {
      WCSession.default.delegate = bridge
      WCSession.default.activate()
    }
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "state", let data = call.arguments as? [String: Any] else {
      result(FlutterMethodNotImplemented); return
    }
    ready = true
    latest = data
    NotificationCenter.default.post(name: Self.stateChanged, object: self)
    publishToWatch()
    result(nil)
  }

  private func publishToWatch() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    guard session.activationState == .activated, session.isPaired,
      session.isWatchAppInstalled, !latest.isEmpty else { return }
    let data = latest
    if CompanionPublicationPolicy.needsImmediateContext(data, after: sentContext) ||
      Date().timeIntervalSince(lastTransfer) >= 15 {
      do {
        try session.updateApplicationContext(data)
        sentContext = data; lastTransfer = Date()
      } catch { /* Keep the previous sample so the next tick retries. */ }
    }
    // Application context is opportunistic background delivery. A visible
    // watch needs the live message path as well, including phone seeks.
    if session.isReachable && !liveTransferPending {
      liveTransferPending = true
      liveTransferGeneration += 1
      let generation = liveTransferGeneration
      func completed() {
        DispatchQueue.main.async {
          if generation == self.liveTransferGeneration {
            self.liveTransferPending = false
            // Deliver a pause/seek/track change that arrived while a prior
            // sample was in flight, rather than waiting for the next timer.
            if CompanionPublicationPolicy.needsImmediateContext(self.latest, after: data) {
              self.publishToWatch()
            }
          }
        }
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: completed)
      session.sendMessage(data, replyHandler: { _ in
        completed()
      }, errorHandler: { _ in
        completed()
      })
    }
  }

  func request(_ method: String, arguments: Any? = nil,
               completion: @escaping (Any?) -> Void) {
    let deadline = Date().addingTimeInterval(12)
    var pending: ((Any?) -> Void)? = completion
    let finish: (Any?) -> Void = { value in
      guard let callback = pending else { return }
      pending = nil // Release the row/watch reply even if Dart never answers.
      callback(value)
    }
    func sendWhenReady() {
      guard pending != nil else { return }
      // A dashboard can connect before Dart installs its handler. Its
      // first state publication proves readiness; a missing handler is
      // not an empty library and never requires unlocking the phone.
      guard self.ready, let channel = self.channel else {
        guard Date() < deadline else {
          finish(["error": "Audio is not ready. Please retry."]); return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: sendWhenReady)
        return
      }
      channel.invokeMethod(method, arguments: arguments) { value in
        if let error = value as? FlutterError {
          finish(["error": error.message ?? "Playback unavailable"])
        } else { finish(value) }
      }
    }
    DispatchQueue.main.async {
      DispatchQueue.main.asyncAfter(deadline: .now() + max(0, deadline.timeIntervalSinceNow)) {
        finish(["error": "Audio request timed out. Please retry."])
      }
      sendWhenReady()
    }
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any],
               replyHandler: @escaping ([String: Any]) -> Void) {
    let action = message["action"] as? String ?? "snapshot"
    if action == "snapshot" {
      request("snapshot", arguments: message) { replyHandler($0 as? [String: Any] ?? [:]) }
    } else if action == "children", let id = message["id"] as? String {
      request("children", arguments: ["id": id]) { value in
        if let failure = value as? [String: Any], failure["error"] != nil {
          replyHandler(failure)
        } else { replyHandler(["items": value as? [[String: Any]] ?? []]) }
      }
    } else if ["play", "pause", "next", "previous", "forward", "backward", "stop", "select", "shuffle", "repeat"].contains(action) {
      request("command", arguments: message) { replyHandler($0 as? [String: Any] ?? [:]) }
    } else { replyHandler(["error": "Unsupported command"]) }
  }

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
               error: Error?) {
    DispatchQueue.main.async { self.sentContext = [:]; self.publishToWatch() }
  }
  func sessionReachabilityDidChange(_ session: WCSession) {
    DispatchQueue.main.async { self.publishToWatch() }
  }
  func sessionDidBecomeInactive(_ session: WCSession) {}
  func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}

#endif
