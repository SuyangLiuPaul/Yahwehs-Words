import Flutter
import WatchConnectivity

/// One bridge per Flutter engine. Watch requests are allowlisted commands
/// against the phone's existing media session, never arbitrary URLs.
final class WordsMediaCompanion: NSObject, FlutterPlugin, WCSessionDelegate {
  static let shared = WordsMediaCompanion()
  private(set) var channel: FlutterMethodChannel?
  private var latest: [String: Any] = [:]
  private var sentIdentity = ""
  private var lastTransfer = Date.distantPast

  static func register(with registrar: FlutterPluginRegistrar) {
    let bridge = shared
    let channel = FlutterMethodChannel(name: "yswords/media_companion",
                                       binaryMessenger: registrar.messenger())
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
    latest = data
    if WCSession.isSupported(), WCSession.default.activationState == .activated,
       WCSession.default.isPaired, WCSession.default.isWatchAppInstalled {
      let identity = "\(data["id"] ?? "")/\(data["playing"] ?? false)/\(data["error"] ?? "")"
      // Coalesce position updates to spare the watch radio. Pause/change
      // metadata publishes immediately, so controls never wait 15 seconds.
      if identity != sentIdentity || Date().timeIntervalSince(lastTransfer) >= 15 {
        do {
          try WCSession.default.updateApplicationContext(data)
          sentIdentity = identity; lastTransfer = Date()
        } catch { /* A disconnected watch retains its last daily verse. */ }
      }
    }
    result(nil)
  }

  func request(_ method: String, arguments: Any? = nil,
               completion: @escaping (Any?) -> Void) {
    DispatchQueue.main.async {
      guard let channel = self.channel else {
        completion(["error": "Open Words on your iPhone to connect."]); return
      }
      channel.invokeMethod(method, arguments: arguments) { value in
        if let error = value as? FlutterError {
          completion(["error": error.message ?? "Playback unavailable"])
        } else { completion(value) }
      }
    }
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any],
               replyHandler: @escaping ([String: Any]) -> Void) {
    let action = message["action"] as? String ?? "snapshot"
    if action == "snapshot" {
      request("snapshot") { replyHandler($0 as? [String: Any] ?? [:]) }
    } else if action == "children", let id = message["id"] as? String {
      request("children", arguments: ["id": id]) { value in
        if let failure = value as? [String: Any], failure["error"] != nil {
          replyHandler(failure)
        } else { replyHandler(["items": value as? [[String: Any]] ?? []]) }
      }
    } else if ["play", "pause", "next", "previous", "forward", "backward", "stop", "select"].contains(action) {
      request("command", arguments: message) { replyHandler($0 as? [String: Any] ?? [:]) }
    } else { replyHandler(["error": "Unsupported command"]) }
  }

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
               error: Error?) {}
  func sessionDidBecomeInactive(_ session: WCSession) {}
  func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
