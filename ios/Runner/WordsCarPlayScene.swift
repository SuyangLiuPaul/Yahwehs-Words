#if CARPLAY_ENABLED
import CarPlay
import Flutter
import UIKit

/// Everything the car screen can be styled with: the images. CarPlay owns
/// the colours, fonts and layout of its templates; an app controls the
/// artwork, so the artwork carries the brand — themed tiles for folders,
/// the real cover for a song, and the themed logo where a cover is missing.
@available(iOS 14.0, *)
enum WordsBrand {
  private static let cache = NSCache<NSString, UIImage>()

  /// The phone's theme colour (ARGB integer from the Flutter side).
  static var accent: UIColor {
    let argb = WordsMediaCompanion.shared.snapshot["accent"] as? Int ?? 0xFF03A9F4
    return UIColor(red: CGFloat((argb >> 16) & 0xFF) / 255, green: CGFloat((argb >> 8) & 0xFF) / 255,
                   blue: CGFloat(argb & 0xFF) / 255, alpha: 1)
  }

  /// The themed logo, the same 512 px mark the website and the phone use.
  static var logoURL: String {
    let logo = WordsMediaCompanion.shared.snapshot["logo"] as? String ?? "Default"
    return "https://yahwehword.com/icons/Icon-\(logo == "Default" ? "" : logo + "-")512.png"
  }

  static var rowSize: CGSize {
    let m = CPListItem.maximumImageSize
    return m.width > 0 ? m : CGSize(width: 60, height: 60)
  }

  private static func darker(_ c: UIColor, _ f: CGFloat) -> UIColor {
    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    return UIColor(hue: h, saturation: min(1, s * 1.05), brightness: max(0, b * f), alpha: 1)
  }

  /// A rounded tile in the theme colour with a white symbol: one consistent
  /// look for every folder, replacing the mixed black glyphs.
  static func tile(symbol: String, size: CGSize = rowSize) -> UIImage {
    let key = "tile|\(symbol)|\(Int(size.width))|\(WordsMediaCompanion.shared.snapshot["accent"] as? Int ?? 0)" as NSString
    if let hit = cache.object(forKey: key) { return hit }
    let renderer = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 3; return f }())
    let image = renderer.image { ctx in
      let rect = CGRect(origin: .zero, size: size)
      let path = UIBezierPath(roundedRect: rect, cornerRadius: size.width * 0.22)
      path.addClip()
      let colors = [accent.withAlphaComponent(1).cgColor, darker(accent, 0.62).cgColor] as CFArray
      if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
        ctx.cgContext.drawLinearGradient(g, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size.width, y: size.height), options: [])
      }
      let config = UIImage.SymbolConfiguration(pointSize: size.width * 0.46, weight: .semibold)
      if let sym = UIImage(systemName: symbol, withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
        let s = sym.size
        sym.draw(in: CGRect(x: (size.width - s.width) / 2, y: (size.height - s.height) / 2, width: s.width, height: s.height))
      }
    }
    cache.setObject(image, forKey: key)
    return image
  }

  /// A cover scaled to fill a rounded square.
  static func rounded(_ image: UIImage, size: CGSize = rowSize) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = 3; return f }())
    return renderer.image { _ in
      UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: size.width * 0.22).addClip()
      let r = max(size.width / image.size.width, size.height / image.size.height)
      let w = image.size.width * r, h = image.size.height * r
      image.draw(in: CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h))
    }
  }

  /// Fetches an artwork URL (cached), rounds it, and hands it back on the
  /// main queue. A failure simply leaves the tile that is already showing.
  static func artwork(_ urlString: String, completion: @escaping (UIImage) -> Void) {
    guard !urlString.isEmpty, let url = URL(string: urlString), url.scheme == "https" else { return }
    let key = "art|\(urlString)" as NSString
    if let hit = cache.object(forKey: key) { completion(hit); return }
    URLSession.shared.dataTask(with: url) { data, _, _ in
      guard let data = data, let raw = UIImage(data: data) else { return }
      let image = rounded(raw)
      cache.setObject(image, forKey: key)
      DispatchQueue.main.async { completion(image) }
    }.resume()
  }

  /// A symbol for each sermon topic, so the Sermons tab reads as a set of
  /// different things instead of one waveform repeated. Matched on words in
  /// the topic title; anything new falls back to the waveform.
  static func topicSymbol(_ title: String) -> String {
    let t = title.lowercased()
    let table: [(String, String)] = [
      ("mount", "mountain.2.fill"), ("parable", "text.bubble.fill"), ("beatitude", "sparkles"),
      ("baptism", "drop.fill"), ("antichrist", "exclamationmark.triangle.fill"),
      ("timothy", "envelope.fill"), ("eschatology", "hourglass"), ("hasten", "sun.max.fill"),
      ("death and resurrection", "sunrise.fill"), ("relating", "person.2.fill"),
      ("testimony", "person.crop.circle.fill"), ("vision for the church", "building.columns.fill"),
      ("vision", "eye.fill"), ("direction", "safari.fill"), ("experience", "heart.fill"),
      ("regeneration", "leaf.fill"), ("mission", "paperplane.fill"), ("quality", "star.fill"),
      ("truth", "lightbulb.fill"), ("fydt", "antenna.radiowaves.left.and.right"),
      ("matthew", "book.fill"),
    ]
    for (needle, symbol) in table where t.contains(needle) { return symbol }
    return "waveform"
  }

  /// The symbol for a folder, from its id (and title, for sermon topics).
  static func symbol(for key: String, playable: Bool, title: String = "") -> String {
    if key.hasPrefix("car:topic/") { return topicSymbol(title) }
    if key.contains("sermon") { return "waveform" }
    if key.contains("instrumental") { return "pianokeys" }
    if key == "car:queue" || key.hasPrefix("car:queue-page") { return "list.bullet" }
    if key == "car:playlists" { return "music.note.list" }
    if key.hasPrefix("car:playlist/") { return key.contains("avourite") ? "heart.fill" : "music.note.list" }
    return playable ? "music.note" : "music.note.list"
  }
}

/// The granted phone and dashboard scenes share one playback engine.
@available(iOS 14.0, *)
class WordsCarPlayScene: UIResponder, CPTemplateApplicationSceneDelegate, CPNowPlayingTemplateObserver {
  private var controller: CPInterfaceController?
  private var connection: UUID?
  private var stateObserver: NSObjectProtocol?
  private var modeRequestPending = false
  func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                didConnect interfaceController: CPInterfaceController) {
    controller = interfaceController
    connection = UUID()
    CPNowPlayingTemplate.shared.add(self)
    CPNowPlayingTemplate.shared.isUpNextButtonEnabled = true
    CPNowPlayingTemplate.shared.upNextTitle = text("Playing queue", "播放队列", "播放佇列")
    stateObserver = NotificationCenter.default.addObserver(forName: WordsMediaCompanion.stateChanged, object: nil, queue: .main) { [weak self] _ in self?.updateModes() }
    updateModes()
    _ = (UIApplication.shared.delegate as? AppDelegate)?.ensureMediaEngine()
    showRoot()
  }
  func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                didDisconnectInterfaceController interfaceController: CPInterfaceController) {
    CPNowPlayingTemplate.shared.remove(self)
    if let observer = stateObserver { NotificationCenter.default.removeObserver(observer) }
    stateObserver = nil
    modeRequestPending = false
    connection = nil
    controller = nil // The phone's existing audio session keeps playing.
  }
  private func text(_ en: String, _ hans: String, _ hant: String) -> String {
    let locale = WordsMediaCompanion.shared.locale
    return locale == "zh-Hant" ? hant : locale.hasPrefix("zh") ? hans : en
  }
  func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
    showFolder("car:queue", title: text("Playing queue", "播放队列", "播放佇列"))
  }
  private func updateModes() {
    let state = WordsMediaCompanion.shared.snapshot
    let template = CPNowPlayingTemplate.shared
    let songs = state["sermon"] as? Bool != true && (state["queueCount"] as? Int ?? 0) > 0
    template.isUpNextButtonEnabled = songs
    guard songs else { template.updateNowPlayingButtons([]); return }
    let shuffle = CPNowPlayingImageButton(image: UIImage(systemName: "shuffle")!) { [weak self] _ in
      let on = WordsMediaCompanion.shared.snapshot["shuffled"] as? Bool == true
      self?.changeMode("shuffle", id: on ? "off" : "on")
    }
    shuffle.isSelected = state["shuffled"] as? Bool == true
    let enabled = !modeRequestPending && state["loading"] as? Bool != true &&
      (state["error"] as? String ?? "").isEmpty
    shuffle.isEnabled = enabled
    let mode = state["repeat"] as? String ?? "off"
    let repeatButton = CPNowPlayingImageButton(image: UIImage(systemName: mode == "one" ? "repeat.1" : "repeat")!) { [weak self] _ in
      let current = WordsMediaCompanion.shared.snapshot["repeat"] as? String ?? "off"
      self?.changeMode("repeat", id: current == "off" ? "all" : current == "all" ? "one" : "off")
    }
    repeatButton.isSelected = mode != "off"
    repeatButton.isEnabled = enabled
    template.updateNowPlayingButtons([shuffle, repeatButton])
  }
  private func changeMode(_ action: String, id: String) {
    guard !modeRequestPending, let connection = connection else { return }
    modeRequestPending = true
    updateModes()
    WordsMediaCompanion.shared.request("command", arguments: ["action":action, "id":id]) { [weak self] result in
      guard let self = self, self.connection == connection else { return }
      self.modeRequestPending = false
      self.updateModes()
      if let error = (result as? [String: Any])?["error"] as? String, !error.isEmpty {
        self.showError(error)
      }
    }
  }
  private func presentationFinished(_ success: Bool, _ error: Error?) {
    // CarPlay raises a native exception on failed presentation when its
    // completion is nil. A rejected template must never terminate audio.
    if let error = error { NSLog("Words CarPlay presentation: %@", error.localizedDescription) }
  }
  /// The four tabs of the car's home screen. CarPlay draws the bar; the
  /// icons and the rows under them carry the brand.
  private func showRoot() {
    guard let controller = controller, let connection = connection else { return }
    func tab(_ id: String?, _ en: String, _ hans: String, _ hant: String, _ symbol: String) -> CPListTemplate {
      let title = text(en, hans, hant)
      let t = CPListTemplate(title: title, sections: [])
      t.tabTitle = title
      t.tabImage = UIImage(systemName: symbol) ?? UIImage()
      t.emptyViewTitleVariants = [text("Loading audio…", "正在加载音频…", "正在載入音訊…")]
      t.emptyViewSubtitleVariants = [text("Connecting to your library", "正在连接音频目录", "正在連接音訊目錄")]
      return t
    }
    let hymns = tab("car:songs", "Hymns", "诗歌", "詩歌", "music.note.list")
    let instrumental = tab("car:instrumental", "Instrumental", "伴奏", "伴奏", "pianokeys")
    let sermons = tab("car:sermons", "Sermons", "讲道", "講道", "waveform")
    let library = tab(nil, "Library", "我的", "我的", "books.vertical.fill")
    let bar = CPTabBarTemplate(templates: [hymns, instrumental, sermons, library])
    controller.setRootTemplate(bar, animated: false, completion: presentationFinished)
    loadFolder("car:songs", title: hymns.title ?? "", template: hymns, connection: connection, nowPlayingRow: true)
    loadFolder("car:instrumental", title: instrumental.title ?? "", template: instrumental, connection: connection, nowPlayingRow: true)
    loadFolder("car:sermons", title: sermons.title ?? "", template: sermons, connection: connection, nowPlayingRow: true)
    loadLibrary(template: library, connection: connection)
  }

  /// Playing queue and playlists, behind the logo.
  private func loadLibrary(template: CPListTemplate, connection: UUID) {
    WordsMediaCompanion.shared.request("children", arguments: ["id": "car:root"]) { [weak self, weak template] value in
      guard let self = self, let template = template, self.connection == connection, self.controller != nil else { return }
      let records = (value as? [[String: Any]] ?? []).filter { ["car:queue", "car:playlists"].contains($0["id"] as? String ?? "") }
      var items: [CPListItem] = []
      let hero = CPListItem(text: "Yahweh’s Words",
                            detailText: self.text("Hymns, instrumental and sermons", "诗歌、伴奏和讲道", "詩歌、伴奏和講道"),
                            image: WordsBrand.tile(symbol: "book.closed.fill"))
      WordsBrand.artwork(WordsBrand.logoURL) { [weak hero] image in hero?.setImage(image) }
      hero.handler = { [weak self] _, complete in
        complete()
        guard let self = self, self.connection == connection, let controller = self.controller else { return }
        if controller.topTemplate !== CPNowPlayingTemplate.shared {
          controller.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: self.presentationFinished)
        }
      }
      items.append(hero)
      var rows: [CPListItem] = []
      for row in records { rows.append(self.makeItem(row, title: template.title ?? "", template: template, connection: connection)) }
      var sections = [CPListSection(items: items)]
      if !rows.isEmpty { sections.append(CPListSection(items: rows)) }
      template.updateSections(sections)
    }
  }

  private func showFolder(_ id: String, title: String, root: Bool = false) {
    guard let controller = controller, let connection = connection else { return }
    let template = CPListTemplate(title: title, sections: [])
    template.emptyViewTitleVariants = [text("Loading audio…", "正在加载音频…", "正在載入音訊…")]
    template.emptyViewSubtitleVariants = [text("Connecting to your library", "正在连接音频目录", "正在連接音訊目錄")]
    if root { controller.setRootTemplate(template, animated: false, completion: presentationFinished) }
    else { controller.pushTemplate(template, animated: true, completion: presentationFinished) }
    loadFolder(id, title: title, template: template, connection: connection)
  }
  private func loadFolder(_ id: String, title: String, template: CPListTemplate, connection: UUID,
                          nowPlayingRow: Bool = false) {
    WordsMediaCompanion.shared.request("children", arguments: ["id": id]) { [weak self, weak template] value in
      guard let self = self, let template = template,
            self.connection == connection, self.controller != nil else { return }
      if let failure = value as? [String: Any], let error = failure["error"] as? String {
        let retry = CPListItem(text: self.text("Retry", "重试", "重試"), detailText: error,
                               image: WordsBrand.tile(symbol: "arrow.clockwise"))
        retry.handler = { [weak self, weak template] _, complete in
          complete()
          guard let template = template, self?.connection == connection else { return }
          template.updateSections([])
          self?.loadFolder(id, title: title, template: template, connection: connection, nowPlayingRow: nowPlayingRow)
        }
        template.updateSections([CPListSection(items: [retry])])
        return
      }
      let records = value as? [[String: Any]] ?? []
      let rows = records.prefix(CPListTemplate.maximumItemCount).map {
        self.makeItem($0, title: title, template: template, connection: connection)
      }
      template.emptyViewTitleVariants = [self.text("No audio available", "暂无音频", "暫無音訊")]
      template.emptyViewSubtitleVariants = [self.text("Choose another category.", "请选择其他分类。", "請選擇其他分類。")]
      var sections: [CPListSection] = []
      // What is playing, on top of every tab, with its cover — one tap to
      // the full Now Playing screen.
      if nowPlayingRow, let playing = self.nowPlayingItem(connection: connection) {
        sections.append(CPListSection(items: [playing]))
      }
      sections.append(CPListSection(items: rows))
      template.updateSections(sections)
    }
  }

  /// "Now playing" row for the top of a tab, or nil when nothing is loaded.
  private func nowPlayingItem(connection: UUID) -> CPListItem? {
    let state = WordsMediaCompanion.shared.snapshot
    let title = state["title"] as? String ?? ""
    guard !title.isEmpty else { return nil }
    let item = CPListItem(text: title,
                          detailText: (state["subtitle"] as? String).flatMap { $0.isEmpty ? nil : $0 }
                            ?? text("Now playing", "正在播放", "正在播放"),
                          image: WordsBrand.tile(symbol: "play.circle.fill"))
    item.isPlaying = state["playing"] as? Bool == true
    item.playingIndicatorLocation = .trailing
    if let art = state["artwork"] as? String { WordsBrand.artwork(art) { [weak item] image in item?.setImage(image) } }
    item.handler = { [weak self] _, complete in
      complete()
      guard let self = self, self.connection == connection, let controller = self.controller else { return }
      if controller.topTemplate !== CPNowPlayingTemplate.shared {
        controller.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: self.presentationFinished)
      }
    }
    return item
  }

  /// One row: a themed tile for folders, the real cover for a song (loaded
  /// in behind the tile), a playing indicator on the current track.
  private func makeItem(_ row: [String: Any], title: String, template: CPListTemplate, connection: UUID) -> CPListItem {
    let key = row["id"] as? String ?? ""
    let playable = row["playable"] as? Bool ?? false
    let item = CPListItem(text: row["title"] as? String ?? text("Audio", "音频", "音訊"),
                          detailText: row["subtitle"] as? String,
                          image: WordsBrand.tile(symbol: WordsBrand.symbol(for: key, playable: playable, title: row["title"] as? String ?? "")))
    item.accessoryType = playable ? .none : .disclosureIndicator
    // A song's own cover, or a source's own logo (FYDT, CDC, CGDC…): fetched
    // in behind the tile. Folders with only the shared themed logo keep the tile.
    let art = row["artwork"] as? String ?? ""
    if !art.isEmpty, art != WordsBrand.logoURL { WordsBrand.artwork(art) { [weak item] image in item?.setImage(image) } }
    if playable {
      if (WordsMediaCompanion.shared.snapshot["id"] as? String ?? "") == key, !key.isEmpty {
        item.isPlaying = WordsMediaCompanion.shared.snapshot["playing"] as? Bool == true
        item.playingIndicatorLocation = .trailing
      }
    }
    item.handler = { [weak self] _, complete in
      NSLog("Words CarPlay: tapped %@ (playable: %@)", key, playable ? "yes" : "no")
      guard self?.connection == connection else { complete(); return }
      if playable {
        WordsMediaCompanion.shared.request("command", arguments: ["action": "select", "id": key]) { [weak self] result in
          complete()
          guard let self = self, self.connection == connection, let controller = self.controller else { return }
          if let error = (result as? [String: Any])?["error"] as? String, !error.isEmpty {
            self.showError(error)
          } else if controller.topTemplate !== CPNowPlayingTemplate.shared {
            CPNowPlayingTemplate.shared.upNextTitle = self.text("Playing queue", "播放队列", "播放佇列")
            if controller.templates.contains(where: { $0 === CPNowPlayingTemplate.shared }) {
              controller.pop(to: CPNowPlayingTemplate.shared, animated: true, completion: self.presentationFinished)
            } else {
              controller.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: self.presentationFinished)
            }
          }
        }
      } else {
        let paging = key.hasPrefix("car:queue-page/") ||
          (key.hasPrefix("car:playlist/") && (Int(key.split(separator: "/").last ?? "0") ?? 0) > 0)
        if paging {
          template.updateSections([])
          self?.loadFolder(key, title: title, template: template, connection: connection)
        } else { self?.showFolder(key, title: row["title"] as? String ?? title) }
        complete()
      }
    }
    return item
  }
  private func showError(_ message: String) {
    guard let controller = controller else { return }
    let close = CPAlertAction(title: text("OK", "确定", "確定"), style: .default) { [weak self] _ in
      guard let self = self else { return }
      self.controller?.dismissTemplate(animated: true, completion: self.presentationFinished)
    }
    controller.presentTemplate(CPAlertTemplate(titleVariants: [message], actions: [close]), animated: true, completion: presentationFinished)
  }
}

class WordsPhoneScene: FlutterSceneDelegate {
  private var sharedEngine: FlutterEngine?
  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
                      options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene,
          let app = UIApplication.shared.delegate as? AppDelegate else { return }
    let engine = app.ensureMediaEngine()
    sharedEngine = engine
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    self.window = window
    registerSceneLifeCycle(with: engine)
    window.makeKeyAndVisible()
    // Preserve plugin URL, user-activity and lifecycle dispatch on the
    // shared engine instead of falling back through a nil app.window.
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }
  override func sceneDidDisconnect(_ scene: UIScene) {
    // The engine outlives this phone window while dashboard audio runs.
    // WKWebView's plugin destroys its channels on sceneDidDisconnect;
    // remove the retained engine from dispatch before forwarding it.
    if let engine = sharedEngine {
      unregisterSceneLifeCycle(with: engine)
      if engine.viewController === window?.rootViewController { engine.viewController = nil }
    }
    window?.rootViewController = nil
    window = nil
    sharedEngine = nil
    super.sceneDidDisconnect(scene)
  }
}
#endif
