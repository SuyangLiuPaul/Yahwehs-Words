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
  func accept(_ value: [String: Any]) {
    DispatchQueue.main.async {
      self.state = value
      self.error = value["error"] as? String ?? ""
      UserDefaults.standard.set(value, forKey: "words.lastState")
    }
  }
  func send(_ action: String, id: String? = nil, reply: (([[String: Any]]) -> Void)? = nil) {
    let session = WCSession.default
    guard session.activationState == .activated, session.isReachable else {
      connected = false
      error = "Connect to Words on your iPhone. Your saved verse is still available."
      reply?([])
      return
    }
    var data: [String: Any] = ["action": action]
    if let id = id { data["id"] = id }
    session.sendMessage(data, replyHandler: { value in
      if action == "children" {
        DispatchQueue.main.async {
          self.error = value["error"] as? String ?? ""
          reply?(value["items"] as? [[String: Any]] ?? [])
        }
      } else { self.accept(value) }
    }, errorHandler: { _ in
      DispatchQueue.main.async {
        self.error = "iPhone unavailable. Try again when connected."
        reply?([])
      }
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
    let playing = companion.state["playing"] as? Bool ?? false
    let sermon = companion.state["sermon"] as? Bool ?? false
    ScrollView {
      VStack(spacing: 10) {
        Text((companion.state["title"] as? String ?? "").isEmpty ? "Choose audio from Listen" : companion.state["title"] as? String ?? "").font(.headline).multilineTextAlignment(.center)
        Text(companion.state["subtitle"] as? String ?? "").font(.caption2).foregroundStyle(.secondary)
        HStack(spacing: 4) {
          transport(sermon ? "backward" : "previous", image: sermon ? "gobackward.15" : "backward.end.fill", label: sermon ? "Back 15 seconds" : "Previous hymn")
          transport(playing ? "pause" : "play", image: playing ? "pause.fill" : "play.fill", label: playing ? "Pause" : "Play")
          transport(sermon ? "forward" : "next", image: sermon ? "goforward.30" : "forward.end.fill", label: sermon ? "Forward 30 seconds" : "Next hymn")
        }.disabled(!companion.connected || (companion.state["id"] as? String ?? "").isEmpty)
        if let p = companion.state["position"] as? Int, let d = companion.state["duration"] as? Int, d > 0 {
          ProgressView(value: Double(min(p,d)), total: Double(d))
          Text("\(p/60):\(String(format:"%02d",p%60)) / \(d/60):\(String(format:"%02d",d%60))").font(.caption2)
        }
        if !companion.error.isEmpty { Text(companion.error).font(.caption2).foregroundStyle(.orange) }
        Text("Audio plays on iPhone").font(.caption2).foregroundStyle(.secondary)
      }.padding(.horizontal, 4)
    }.navigationTitle("Now playing")
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
      companion.send("children", id:id) { items = $0; loading = false }
  }
}
