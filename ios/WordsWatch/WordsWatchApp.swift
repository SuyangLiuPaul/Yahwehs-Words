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


/// The phone's theme as the watch shows it. The phone sends `accent` (its theme
/// colour, ARGB) and `logo` (which logo variant matches); the watch cannot read
/// the phone's settings, so it follows what it is told. A state with neither —
/// an older phone — keeps the original blue.
struct WatchThemePalette: Equatable {
  typealias RGB = (r: Double, g: Double, b: Double)
  let accent: RGB, surface: RGB, page: RGB, secondary: RGB

  static let logoNames: Set<String> = ["Default", "Red", "Orange", "Green", "Purple", "Pink", "Dark"]

  static let original = WatchThemePalette(
    accent: (0.33, 0.78, 0.96), surface: (0.12, 0.22, 0.30),
    page: (0.04, 0.10, 0.15), secondary: (0.79, 0.86, 0.92))

  static func == (a: WatchThemePalette, b: WatchThemePalette) -> Bool {
    a.accent == b.accent && a.surface == b.surface && a.page == b.page && a.secondary == b.secondary
  }

  /// The asset-catalogue name of the logo for [state] (`LogoRed`, `LogoDefault`, …).
  static func logoName(_ state: [String: Any]) -> String {
    let variant = state["logo"] as? String ?? "Default"
    return "Logo" + (logoNames.contains(variant) ? variant : "Default")
  }

  static func from(_ state: [String: Any]) -> WatchThemePalette {
    guard let number = state["accent"] as? NSNumber else { return original }
    let argb = UInt32(truncatingIfNeeded: number.int64Value)
    var rgb: RGB = (Double((argb >> 16) & 0xFF) / 255, Double((argb >> 8) & 0xFF) / 255, Double(argb & 0xFF) / 255)
    // The watch is dark: a deep theme colour must be lifted to stay legible as
    // text and as a button, without losing its hue.
    let luminance = 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b
    if luminance < 0.45 {
      let t = min(0.65, (0.45 - luminance) / (1 - luminance))
      rgb = (rgb.r + (1 - rgb.r) * t, rgb.g + (1 - rgb.g) * t, rgb.b + (1 - rgb.b) * t)
    }
    func tinted(_ base: Double, _ weight: Double) -> RGB {
      (base + weight * rgb.r, base + weight * rgb.g, base + weight * rgb.b)
    }
    let white: RGB = (1, 1, 1)
    let secondary: RGB = (white.r * 0.8 + rgb.r * 0.2, white.g * 0.8 + rgb.g * 0.2, white.b * 0.8 + rgb.b * 0.2)
    return WatchThemePalette(accent: rgb, surface: tinted(0.06, 0.22), page: tinted(0.03, 0.10), secondary: secondary)
  }
}

#if !WATCH_COMPANION_LOGIC_TEST
import SwiftUI
import WatchConnectivity
import WatchKit

final class WordsWatchDelegate: NSObject, WKApplicationDelegate {
  static let playbackRequested = Notification.Name("WordsWatchPlaybackRequested")
  static let pendingPlaybackKey = "words.pendingPlaybackLaunch"
  /// A request nobody acted on within this long is stale. It was made for a
  /// listener who has long since stopped waiting, and opening the playback
  /// page on some later launch would be a surprise, not a convenience.
  static let pendingPlaybackLifetime: TimeInterval = 60
  func handleRemoteNowPlayingActivity() {
    // The OS chooses whether to launch us. Preserve a cold-launch request
    // until SwiftUI is ready; this does not force the watch into foreground.
    DispatchQueue.main.async {
      UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.pendingPlaybackKey)
      NotificationCenter.default.post(name: Self.playbackRequested, object: nil)
    }
  }
}

@main
struct WordsWatchApp: App {
  @WKApplicationDelegateAdaptor(WordsWatchDelegate.self) private var appDelegate
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var companion = WatchCompanion()
  var body: some Scene {
    WindowGroup {
      WatchHome().environmentObject(companion)
        .onAppear { companion.setForeground(scenePhase == .active) }
        .onChange(of: scenePhase) { phase in companion.setForeground(phase == .active) }
    }
  }
}

final class WatchCompanion: NSObject, ObservableObject, WCSessionDelegate {
  @Published var state: [String: Any] = [:]
  @Published var connected = false
  @Published var error = ""
  override init() {
    super.init()
    state = UserDefaults.standard.dictionary(forKey: "words.lastState") ?? [:]
    WatchStyle.palette = WatchThemePalette.from(state)
    if WCSession.isSupported() {
      WCSession.default.delegate = self
      WCSession.default.activate()
    }
  }
  private var connectionProof = WatchConnectionProof()
  private var pendingRequests = Set<UUID>()
  private var refreshTimer: Timer?
  func setForeground(_ active: Bool) {
    refreshTimer?.invalidate(); refreshTimer = nil
    guard active else { return }
    send("snapshot")
    refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
      guard let self = self, self.pendingRequests.isEmpty, WCSession.default.isReachable else { return }
      self.send("snapshot")
    }
  }
  private func acceptOnMain(_ value: [String: Any]) {
    guard WatchPlaybackSnapshot.accepts(value, after: state) else { return }
    state = value
    WatchStyle.palette = WatchThemePalette.from(value)
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
      error = WatchStyle.text(state,"Connect to Words on your iPhone. Your saved verse is still available.","请连接 iPhone 上的 Words；仍可阅读已保存经文。","請連接 iPhone 上的 Words；仍可閱讀已儲存經文。")
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
      finish(nil, failure: WatchStyle.text(self.state,"iPhone did not reply. Open Words and retry.","iPhone 未回复，请打开 Words 后重试。","iPhone 未回覆，請開啟 Words 後重試。"))
    }
    var data: [String: Any] = ["action": action]
    if let id = id { data["id"] = id }
    session.sendMessage(data, replyHandler: { value in
      DispatchQueue.main.async { finish(value) }
    }, errorHandler: { _ in
      DispatchQueue.main.async { finish(nil, failure: WatchStyle.text(self.state,"iPhone unavailable. Try again when connected.","暂时无法连接 iPhone，请连接后重试。","暫時無法連接 iPhone，請連接後重試。")) }
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
  func session(_ session: WCSession, didReceiveMessage message: [String: Any],
               replyHandler: @escaping ([String: Any]) -> Void) {
    DispatchQueue.main.async {
      self.acceptOnMain(message)
      replyHandler(["received": true])
    }
  }
  func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    accept(applicationContext)
  }
}

enum WatchStyle {
  /// Set from each accepted state (main thread); views read it as they build,
  /// and rebuild whenever the state changes.
  static var palette = WatchThemePalette.original
  private static func color(_ c: WatchThemePalette.RGB) -> Color { Color(red: c.r, green: c.g, blue: c.b) }
  static var accent: Color { color(palette.accent) }
  static var surface: Color { color(palette.surface) }
  static var page: Color { color(palette.page) }
  static var secondary: Color { color(palette.secondary) }
  static let artworkPaper = Color(red: 0.91, green: 0.96, blue: 1.0)
  static func text(_ state: [String: Any], _ en: String, _ hans: String, _ hant: String) -> String {
    let locale = state["locale"] as? String ?? "en"
    return locale == "zh-Hant" ? hant : locale.hasPrefix("zh") ? hans : en
  }
}

struct WatchArtwork: View {
  let state: [String: Any]
  var size: CGFloat = 68
  private var url: URL? {
    guard let raw = state["artwork"] as? String, let url = URL(string: raw),
      url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { return nil }
    return url
  }
  var body: some View {
    AsyncImage(url: url) { phase in
      if let image = phase.image { image.resizable().scaledToFit().padding(3).background(WatchStyle.artworkPaper) }
      else { Image(WatchThemePalette.logoName(state)).resizable().scaledToFill() }
    }.frame(width: size, height: size).background(WatchStyle.surface)
      .clipShape(RoundedRectangle(cornerRadius: 14)).accessibilityHidden(true)
  }
}

struct WatchHome: View {
  @EnvironmentObject var companion: WatchCompanion
  @State private var playbackPresented = false
  var body: some View {
    let state = companion.state
    NavigationStack {
      ScrollView {
        VStack(spacing: 10) {
          HStack(spacing: 6) {
            Image(WatchThemePalette.logoName(state)).resizable().scaledToFit().frame(width: 18, height: 18)
              .clipShape(RoundedRectangle(cornerRadius: 4)).accessibilityHidden(true)
            Text("Yahweh’s Words").font(.caption).fontWeight(.semibold).foregroundStyle(WatchStyle.accent)
          }
          Button { playbackPresented = true } label: {
            VStack(spacing: 8) {
              WatchArtwork(state: state)
              Text((state["title"] as? String ?? "").isEmpty ? WatchStyle.text(state,"Now playing","正在播放","正在播放") : state["title"] as? String ?? "")
                .font(.headline).lineLimit(2).multilineTextAlignment(.center)
              Label(WatchStyle.text(state,"Listen on iPhone","在 iPhone 上聆听","在 iPhone 上聆聽"), systemImage: "iphone").font(.caption2).foregroundStyle(WatchStyle.secondary)
            }.frame(maxWidth: .infinity).padding(12).background(WatchStyle.surface, in: RoundedRectangle(cornerRadius: 18))
          }.buttonStyle(.plain)
          NavigationLink { WatchLibrary(id: "car:root", title: WatchStyle.text(state,"Listen","聆听","聆聽")) } label: { Label(WatchStyle.text(state,"Hymns & sermons","诗歌与讲道","詩歌與講道"), systemImage: "headphones") }
          NavigationLink { WatchBibleView() } label: { Label(WatchStyle.text(state,"Bible · on your phone","圣经 · 手机当前章节","聖經 · 手機目前章節"), systemImage: "text.book.closed") }
          NavigationLink { DailyVerseView() } label: { Label(WatchStyle.text(state,"Daily verse","每日经文","每日經文"), systemImage: "book.closed") }
          Text(companion.connected ? WatchStyle.text(state,"Connected to iPhone","已连接 iPhone","已連接 iPhone") : WatchStyle.text(state,"iPhone offline · saved verse available","iPhone 离线 · 可读已保存经文","iPhone 離線 · 可讀已儲存經文"))
            .font(.caption2).foregroundStyle(WatchStyle.secondary).multilineTextAlignment(.center)
          Button { companion.send("snapshot") } label: { Label(WatchStyle.text(state,"Refresh","刷新","重新整理"), systemImage: "arrow.clockwise") }.font(.caption)
        }.padding(.horizontal, 6)
      }.background(.black)
        .navigationDestination(isPresented: $playbackPresented) { WatchPlaybackView() }
    }.tint(WatchStyle.accent)
      .onAppear { consumePlaybackLaunch() }
      .onReceive(NotificationCenter.default.publisher(for: WordsWatchDelegate.playbackRequested)) { _ in consumePlaybackLaunch() }
  }
  private func consumePlaybackLaunch() {
    let requestedAt = UserDefaults.standard.double(forKey: WordsWatchDelegate.pendingPlaybackKey)
    guard requestedAt > 0 else { return }
    UserDefaults.standard.removeObject(forKey: WordsWatchDelegate.pendingPlaybackKey)
    guard Date().timeIntervalSince1970 - requestedAt <= WordsWatchDelegate.pendingPlaybackLifetime else { return }
    companion.send("snapshot")
    playbackPresented = true
  }
}

struct DailyVerseView: View {
  @EnvironmentObject var companion: WatchCompanion
  var body: some View {
    let daily = companion.state["daily"] as? [String: Any] ?? [:]
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        Image(systemName: "book.closed").foregroundStyle(WatchStyle.accent)
        Text(daily["reference"] as? String ?? WatchStyle.text(companion.state,"Daily verse","每日经文","每日經文")).font(.headline).foregroundStyle(WatchStyle.accent)
        Text(daily["english"] as? String ?? WatchStyle.text(companion.state,"Open Words on iPhone to sync today’s verse.","在 iPhone 打开 Words，同步今日经文。","在 iPhone 開啟 Words，同步今日經文。"))
        Text(daily["chinese"] as? String ?? "").font(.body)
        Text("\(daily["date"] as? String ?? "") · BSB-Y / CUVS-Y").font(.caption2).foregroundStyle(WatchStyle.secondary)
      }.padding(.horizontal, 6)
    }.navigationTitle(WatchStyle.text(companion.state,"Daily verse","每日经文","每日經文"))
  }
}

struct WatchBibleView: View {
  @EnvironmentObject var companion: WatchCompanion
  var body: some View {
    let state = companion.state
    let reading = state["reading"] as? [String: Any] ?? [:]
    let verses = reading["verses"] as? [[String: String]] ?? []
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        Text(reading["reference"] as? String ?? WatchStyle.text(state,"Bible","圣经","聖經")).font(.headline).foregroundStyle(WatchStyle.accent)
        Text(reading["versionLabel"] as? String ?? reading["version"] as? String ?? "").font(.caption2).foregroundStyle(WatchStyle.secondary)
        Text(companion.connected ? WatchStyle.text(state,"Follows the chapter selected on iPhone","跟随 iPhone 所选章节","跟隨 iPhone 所選章節") : WatchStyle.text(state,"Saved chapter · reconnect to update","已保存章节 · 连接后更新","已儲存章節 · 連接後更新")).font(.caption2).foregroundStyle(WatchStyle.secondary)
        if verses.isEmpty { Text(WatchStyle.text(state,"Open a Bible chapter in Words on iPhone, then refresh.","在 iPhone 的 Words 打开圣经章节，然后刷新。","在 iPhone 的 Words 開啟聖經章節，然後重新整理。")) }
        ForEach(verses.indices, id: \.self) { index in
          let verse = verses[index]
          if let heading = verse["heading"], !heading.isEmpty { Text(heading).font(.caption).foregroundStyle(WatchStyle.secondary) }
          Text("\(verse["number"] ?? "")  \(verse["text"] ?? "")").font(.body).fixedSize(horizontal: false, vertical: true)
        }
        if reading["truncated"] as? Bool == true { Text(WatchStyle.text(state,"This chapter exceeds the watch transfer limit. Read the remaining verses on iPhone.","本章超过手表传输上限；其余经文请在 iPhone 阅读。","本章超過手錶傳輸上限；其餘經文請在 iPhone 閱讀。")).font(.caption2).foregroundStyle(WatchStyle.secondary) }
        Button { companion.send("snapshot") } label: { Label(WatchStyle.text(state,"Refresh from iPhone","从 iPhone 刷新","從 iPhone 重新整理"), systemImage: "arrow.clockwise") }
      }.padding(.horizontal, 6)
    }.navigationTitle(WatchStyle.text(state,"Bible","圣经","聖經"))
  }
}

struct WatchPlaybackView: View {
  @EnvironmentObject var companion: WatchCompanion
  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { timeline in playback(now: timeline.date) }
      .navigationTitle(WatchStyle.text(companion.state,"Now playing","正在播放","正在播放"))
  }
  private func playback(now: Date) -> some View {
    let state = companion.state
    let playing = state["playing"] as? Bool ?? false
    let sermon = state["sermon"] as? Bool ?? false
    let live = companion.connected && WatchPlaybackSnapshot.isFresh(state, now: now)
    let enabled = WatchPlaybackSnapshot.canControl(state, now: now, connected: companion.connected, error: companion.error)
    let canPrevious = sermon || (state["canPrevious"] as? Bool ?? state["canSkip"] as? Bool ?? false)
    let canNext = sermon || (state["canNext"] as? Bool ?? state["canSkip"] as? Bool ?? false)
    let elapsed = WatchPlaybackSnapshot.elapsed(state, now: now, connected: companion.connected)
    let total = (state["duration"] as? NSNumber)?.intValue ?? 0
    return ScrollView {
      VStack(spacing: 8) {
        HStack(spacing: 8) {
          WatchArtwork(state: state, size: 44)
          VStack(alignment: .leading, spacing: 3) {
            Text((state["title"] as? String ?? "").isEmpty ? WatchStyle.text(state,"Choose audio from Listen","从聆听选择音频","從聆聽選擇音訊") : state["title"] as? String ?? "")
              .font(.system(.caption, design: .rounded).weight(.semibold)).lineLimit(3)
            Text(state["subtitle"] as? String ?? "").font(.caption2).foregroundStyle(WatchStyle.secondary).lineLimit(2)
          }.frame(maxWidth: .infinity, alignment: .leading)
        }
        HStack(spacing: 8) {
          transport(sermon ? "backward" : "previous", image: sermon ? "gobackward.15" : "backward.end.fill", label: sermon ? WatchStyle.text(state,"Back 15 seconds","快退 15 秒","快退 15 秒") : WatchStyle.text(state,"Previous hymn","上一首","上一首")).disabled(!canPrevious)
          transport(playing ? "pause" : "play", image: playing ? "pause.fill" : "play.fill", label: playing ? WatchStyle.text(state,"Pause","暂停","暫停") : WatchStyle.text(state,"Play","播放","播放"), primary: true)
          transport(sermon ? "forward" : "next", image: sermon ? "goforward.30" : "forward.end.fill", label: sermon ? WatchStyle.text(state,"Forward 30 seconds","快进 30 秒","快進 30 秒") : WatchStyle.text(state,"Next hymn","下一首","下一首")).disabled(!canNext)
        }.disabled(!enabled)
        if !sermon && (state["queueCount"] as? Int ?? 0) > 0 {
          Text("\((state["queueIndex"] as? Int ?? 0) + 1) / \(state["queueCount"] as? Int ?? 0) · \(state["queueLabel"] as? String ?? "")")
            .font(.caption2).foregroundStyle(WatchStyle.secondary).lineLimit(2)
          HStack {
            Button { companion.send("shuffle", id: state["shuffled"] as? Bool == true ? "off" : "on") } label: {
              Label(WatchStyle.text(state,"Shuffle","随机","隨機"), systemImage: "shuffle").font(.caption2)
                .frame(minHeight: 44).foregroundStyle(state["shuffled"] as? Bool == true ? WatchStyle.accent : .white)
            }
            Button { companion.send("repeat", id: state["repeat"] as? String == "off" ? "all" : state["repeat"] as? String == "all" ? "one" : "off") } label: {
              Label(WatchStyle.text(state,"Repeat","循环","循環"), systemImage: state["repeat"] as? String == "one" ? "repeat.1" : "repeat").font(.caption2)
                .frame(minHeight: 44).foregroundStyle(state["repeat"] as? String == "off" ? .white : WatchStyle.accent)
            }
          }.disabled(!enabled)
          Text(WatchStyle.text(state, state["repeat"] as? String == "one" ? "Repeat one" : state["repeat"] as? String == "all" ? "Repeat queue" : "Repeat off", state["repeat"] as? String == "one" ? "单曲循环" : state["repeat"] as? String == "all" ? "列表循环" : "不循环", state["repeat"] as? String == "one" ? "單曲循環" : state["repeat"] as? String == "all" ? "清單循環" : "不循環"))
            .font(.caption2).foregroundStyle(WatchStyle.secondary)
          NavigationLink { WatchLibrary(id:"car:queue", title:WatchStyle.text(state,"Playing queue","播放队列","播放佇列")) } label: {
            Label(WatchStyle.text(state,"Playing queue","播放队列","播放佇列"), systemImage:"list.bullet")
          }.font(.caption)
        }
        if total > 0 { ProgressView(value: Double(elapsed), total: Double(total)).tint(WatchStyle.accent) }
        HStack { Text(WatchPlaybackSnapshot.clock(elapsed)); Spacer(); Text(total > 0 ? WatchPlaybackSnapshot.clock(total) : "—") }.font(.caption2).monospacedDigit().foregroundStyle(WatchStyle.secondary)
        Label(!live ? WatchStyle.text(state,"Saved · reconnect iPhone","已保存 · 重新连接 iPhone","已儲存 · 重新連接 iPhone") : state["loading"] as? Bool == true ? WatchStyle.text(state,"Loading on iPhone…","iPhone 正在加载…","iPhone 正在載入…") : state["playing"] as? Bool == true ? WatchStyle.text(state,"Playing on iPhone","音频在 iPhone 播放","音訊在 iPhone 播放") : WatchStyle.text(state,"Paused on iPhone","iPhone 已暂停","iPhone 已暫停"), systemImage: live ? "iphone" : "iphone.slash")
          .font(.caption2).foregroundStyle(WatchStyle.secondary).multilineTextAlignment(.center)
        if !companion.error.isEmpty { Text(companion.error).font(.caption2).foregroundStyle(WatchStyle.accent) }
        NavigationLink { NowPlayingView() } label: { Label(WatchStyle.text(state,"Volume & system controls","音量与系统控制","音量與系統控制"), systemImage: "speaker.wave.2") }.font(.caption)
        Button { companion.send("snapshot") } label: { Label(WatchStyle.text(state,"Refresh","刷新","重新整理"), systemImage: "arrow.clockwise") }.font(.caption)
      }.padding(.horizontal, 4)
    }.background(WatchStyle.page).foregroundStyle(.white)
  }
  func transport(_ action: String, image: String, label: String, primary: Bool = false) -> some View {
    Button { companion.send(action) } label: {
      Image(systemName: image).font(.system(size: primary ? 21 : 18, weight: .semibold))
        .frame(minWidth: primary ? 52 : 44, minHeight: primary ? 52 : 44)
        .foregroundStyle(primary ? .black : .white)
    }.buttonStyle(.plain).background(primary ? WatchStyle.accent : WatchStyle.surface, in: Circle()).accessibilityLabel(label)
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
      if !companion.connected { Text(WatchStyle.text(companion.state,"Connect your iPhone to browse and play audio.","连接 iPhone 后可浏览和播放音频。","連接 iPhone 後可瀏覽和播放音訊。")) }
      else if loading { ProgressView() }
      else if items.isEmpty && companion.error.isEmpty { Text(WatchStyle.text(companion.state,"No audio in this category.","此分类暂无音频。","此分類暫無音訊。")) }
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
      Button(WatchStyle.text(companion.state,"Retry","重试","重試")) { load() }.disabled(!companion.connected || loading)
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
