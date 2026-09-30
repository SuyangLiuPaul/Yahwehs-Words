import Foundation

// Pure snapshot rules shared by the display and focused native checks.
struct WatchPlaybackSnapshot {
  static func timestamp(_ state: [String: Any]) -> Double {
    (state["syncedAt"] as? NSNumber)?.doubleValue ?? 0
  }
  static func accepts(_ incoming: [String: Any], after current: [String: Any]) -> Bool {
    timestamp(incoming) >= timestamp(current)
  }
  static func isFresh(_ state: [String: Any], now: Date) -> Bool {
    let stamp = timestamp(state)
    let age = now.timeIntervalSince1970 * 1000 - stamp
    return stamp > 0 && age >= -5000 && age <= 45000
  }
  static func elapsed(_ state: [String: Any], now: Date, connected: Bool) -> Int {
    let sampled = max(0, (state["position"] as? NSNumber)?.intValue ?? 0)
    let total = max(0, (state["duration"] as? NSNumber)?.intValue ?? 0)
    let advances = connected && isFresh(state, now: now) &&
      state["playing"] as? Bool == true && state["loading"] as? Bool != true &&
      (state["error"] as? String ?? "").isEmpty
    let age = max(0, now.timeIntervalSince1970 - timestamp(state) / 1000)
    let position = sampled + (advances ? Int(age) : 0)
    return total > 0 ? min(position, total) : position
  }
  static func canControl(_ state: [String: Any], now: Date, connected: Bool, error: String) -> Bool {
    connected && isFresh(state, now: now) && error.isEmpty &&
      state["loading"] as? Bool != true && (state["error"] as? String ?? "").isEmpty &&
      !(state["id"] as? String ?? "").isEmpty
  }
  static func clock(_ seconds: Int) -> String {
    let value = max(0, seconds)
    return value >= 3600 ? String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
      : String(format: "%d:%02d", value / 60, value % 60)
  }
}

struct WatchConnectionProof {
  private(set) var generation = 0
  mutating func received() { generation += 1 }
  func canFail(requestGeneration: Int) -> Bool { generation == requestGeneration }
}

#if !WATCH_COMPANION_LOGIC_TEST
import SwiftUI
import WatchConnectivity

@main
struct WordsWatchApp: App {
  @StateObject private var companion = WatchCompanion()
  var body: some Scene {
    WindowGroup { WatchHome().environmentObject(companion) }
  }
}

final class WatchCompanion: NSObject, ObservableObject, WCSessionDelegate {
  @Published var state: [String: Any] = [:]
  @Published var connected = false
  @Published var error = ""
  override init() {
    super.init()
    state = UserDefaults.standard.dictionary(forKey: "words.lastState") ?? [:]
    if WCSession.isSupported() {
      WCSession.default.delegate = self
      WCSession.default.activate()
    }
  }
  private var connectionProof = WatchConnectionProof()
  private var pendingRequests = Set<UUID>()
  private func acceptOnMain(_ value: [String: Any]) {
    guard WatchPlaybackSnapshot.accepts(value, after: state) else { return }
    state = value
    if WatchPlaybackSnapshot.isFresh(value, now: Date()) {
      connectionProof.received()
      connected = WCSession.default.isReachable
      error = value["error"] as? String ?? ""
    }
    UserDefaults.standard.set(value, forKey: "words.lastState")
  }
  func accept(_ value: [String: Any]) {
    DispatchQueue.main.async { self.acceptOnMain(value) }
  }
  func send(_ action: String, id: String? = nil, reply: (([[String: Any]]) -> Void)? = nil) {
    let session = WCSession.default
    guard session.activationState == .activated, session.isReachable else {
      connected = false
      error = "Connect to Words on your iPhone. Your saved verse is still available."
      reply?([])
      return
    }
    let request = UUID()
    let proofAtRequest = connectionProof.generation
    pendingRequests.insert(request)
    var completion = reply
    func finish(_ value: [String: Any]?, failure: String? = nil) {
      guard self.pendingRequests.remove(request) != nil else { return }
      let callback = completion
      completion = nil
      if let failure = failure {
        if self.connectionProof.canFail(requestGeneration: proofAtRequest) {
          self.connected = false
          self.error = failure
        }
        callback?([])
      } else if let value = value {
        if action == "children" || value["syncedAt"] == nil {
          let currentRequest = self.connectionProof.canFail(requestGeneration: proofAtRequest)
          self.connectionProof.received()
          self.connected = session.isReachable
          if (value["error"] as? String ?? "").isEmpty || currentRequest {
            self.error = value["error"] as? String ?? ""
          }
          callback?(value["items"] as? [[String: Any]] ?? [])
        } else { self.acceptOnMain(value) }
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
      finish(nil, failure: "iPhone did not reply. Open Words and retry.")
    }
    var data: [String: Any] = ["action": action]
    if let id = id { data["id"] = id }
    session.sendMessage(data, replyHandler: { value in
      DispatchQueue.main.async { finish(value) }
    }, errorHandler: { _ in
      DispatchQueue.main.async { finish(nil, failure: "iPhone unavailable. Try again when connected.") }
    })
  }
  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    DispatchQueue.main.async { self.connected = session.isReachable; self.send("snapshot") }
  }
  func sessionReachabilityDidChange(_ session: WCSession) {
    DispatchQueue.main.async { self.connected = session.isReachable
      if self.connected { self.send("snapshot") }
    }
  }
  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    accept(applicationContext)
  }
}

struct WatchHome: View {
  @EnvironmentObject var companion: WatchCompanion
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 12) {
          Text("Yahweh’s Words").font(.headline).foregroundStyle(.orange)
          NavigationLink { DailyVerseView() } label: { Label("Daily verse · 每日经文", systemImage: "book.closed") }
          NavigationLink { WatchPlaybackView() } label: { Label("Now playing · 播放", systemImage: "play.circle") }
          NavigationLink { WatchLibrary(id: "car:root", title: "Listen · 聆听") } label: { Label("Hymns & sermons", systemImage: "headphones") }
          Text(companion.connected ? "Connected to iPhone" : "iPhone offline · saved verse available")
            .font(.caption2).foregroundStyle(.secondary)
          Button("Refresh · 刷新") { companion.send("snapshot") }
        }.padding(.horizontal, 6)
      }
    }.tint(.orange)
  }
}

struct DailyVerseView: View {
  @EnvironmentObject var companion: WatchCompanion
  var body: some View {
    let daily = companion.state["daily"] as? [String: Any] ?? [:]
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        Text(daily["reference"] as? String ?? "Daily verse").font(.headline).foregroundStyle(.orange)
        Text(daily["english"] as? String ?? "Open Words on your iPhone to sync today’s verse.")
        Text(daily["chinese"] as? String ?? "").font(.body)
        Text("\(daily["date"] as? String ?? "") · BSB-Y / CUVS-Y")
          .font(.caption2).foregroundStyle(.secondary)
      }.padding(.horizontal, 6)
    }.navigationTitle("Daily verse")
  }
}

struct WatchPlaybackView: View {
  @EnvironmentObject var companion: WatchCompanion
  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { timeline in
      playback(now: timeline.date)
    }.navigationTitle("Now playing")
  }
  private func playback(now: Date) -> some View {
    let state = companion.state
    let playing = state["playing"] as? Bool ?? false
    let sermon = state["sermon"] as? Bool ?? false
    let live = companion.connected && WatchPlaybackSnapshot.isFresh(state, now: now)
    let enabled = WatchPlaybackSnapshot.canControl(state, now: now, connected: companion.connected, error: companion.error)
    let canSkip = sermon || state["canSkip"] as? Bool == true
    let elapsed = WatchPlaybackSnapshot.elapsed(state, now: now, connected: companion.connected)
    let total = (state["duration"] as? NSNumber)?.intValue ?? 0
    return ScrollView {
      VStack(spacing: 10) {
        Text((state["title"] as? String ?? "").isEmpty ? "Choose audio from Listen" : state["title"] as? String ?? "").font(.headline).multilineTextAlignment(.center)
        Text(state["subtitle"] as? String ?? "").font(.caption2).foregroundStyle(.secondary)
        HStack(spacing: 4) {
          transport(sermon ? "backward" : "previous", image: sermon ? "gobackward.15" : "backward.end.fill", label: sermon ? "Back 15 seconds" : "Previous hymn").disabled(!canSkip)
          transport(playing ? "pause" : "play", image: playing ? "pause.fill" : "play.fill", label: playing ? "Pause" : "Play")
          transport(sermon ? "forward" : "next", image: sermon ? "goforward.30" : "forward.end.fill", label: sermon ? "Forward 30 seconds" : "Next hymn").disabled(!canSkip)
        }.disabled(!enabled)
        if total > 0 { ProgressView(value: Double(elapsed), total: Double(total)) }
        Text("\(WatchPlaybackSnapshot.clock(elapsed)) / \(total > 0 ? WatchPlaybackSnapshot.clock(total) : "—")").font(.caption2).monospacedDigit()
        if !companion.error.isEmpty { Text(companion.error).font(.caption2).foregroundStyle(.orange) }
        Text(!live ? "Saved playback · Refresh to connect" : state["loading"] as? Bool == true ? "Loading on iPhone…" : "Audio plays on iPhone")
          .font(.caption2).foregroundStyle(.secondary)
        Button("Refresh · 刷新") { companion.send("snapshot") }
      }.padding(.horizontal, 4)
    }
  }
  func transport(_ action: String, image: String, label: String) -> some View {
    Button { companion.send(action) } label: {
      Image(systemName: image).frame(minWidth: 44, minHeight: 44)
    }.buttonStyle(.plain).background(.gray.opacity(0.22), in: Circle()).accessibilityLabel(label)
  }
}

struct WatchLibrary: View {
  @EnvironmentObject var companion: WatchCompanion
  let id: String
  let title: String
  @State private var items: [[String: Any]] = []
  @State private var loading = true
  @State private var requestVersion = 0
  var body: some View {
    List {
      if !companion.connected { Text("Connect your iPhone to browse and play audio.") }
      else if loading { ProgressView() }
      else if items.isEmpty && companion.error.isEmpty { Text("No audio in this category.") }
      ForEach(items.indices, id: \.self) { index in
        let item = items[index]
        let name = item["title"] as? String ?? "Audio"
        let key = item["id"] as? String ?? ""
        if item["playable"] as? Bool == true {
          Button(name) { companion.send("select", id: key) }
        } else {
          NavigationLink(name) { WatchLibrary(id:key, title:name) }
        }
      }
      if !companion.error.isEmpty { Text(companion.error).font(.caption2) }
      Button("Retry · 重试") { load() }.disabled(!companion.connected || loading)
    }.navigationTitle(title).task(id: companion.connected) { load() }
  }
  private func load() {
      loading = companion.connected
      guard companion.connected else { return }
      requestVersion += 1
      let version = requestVersion
      companion.send("children", id:id) {
        guard version == requestVersion else { return }
        items = $0; loading = false
      }
  }
}

#endif
