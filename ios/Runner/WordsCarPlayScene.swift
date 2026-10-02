#if CARPLAY_ENABLED
import CarPlay
import Flutter
import UIKit

/// The granted phone and dashboard scenes share one playback engine.
@available(iOS 14.0, *)
class WordsCarPlayScene: UIResponder, CPTemplateApplicationSceneDelegate, CPNowPlayingTemplateObserver {
  private var controller: CPInterfaceController?
  private var connection: UUID?
  private var stateObserver: NSObjectProtocol?
  func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                didConnect interfaceController: CPInterfaceController) {
    controller = interfaceController
    connection = UUID()
    CPNowPlayingTemplate.shared.add(self)
    CPNowPlayingTemplate.shared.isUpNextButtonEnabled = true
    CPNowPlayingTemplate.shared.upNextTitle = text("Playing queue", "播放队列", "播放佇列")
    stateObserver = NotificationCenter.default.addObserver(forName: WordsMediaCompanion.stateChanged, object: nil, queue: .main) { [weak self] _ in self?.updateModes() }
    updateModes()
    (UIApplication.shared.delegate as? AppDelegate)?.ensureMediaEngine()
    showFolder("car:root", title: "Yahweh’s Words", root: true)
  }
  func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                didDisconnect interfaceController: CPInterfaceController) {
    CPNowPlayingTemplate.shared.remove(self)
    if let observer = stateObserver { NotificationCenter.default.removeObserver(observer) }
    stateObserver = nil
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
    let shuffle = CPNowPlayingImageButton(image: UIImage(systemName: "shuffle")!) { _ in
      let on = WordsMediaCompanion.shared.snapshot["shuffled"] as? Bool == true
      WordsMediaCompanion.shared.request("command", arguments: ["action":"shuffle", "id":on ? "off" : "on"]) { _ in }
    }
    shuffle.isSelected = state["shuffled"] as? Bool == true
    let mode = state["repeat"] as? String ?? "off"
    let repeatButton = CPNowPlayingImageButton(image: UIImage(systemName: mode == "one" ? "repeat.1" : "repeat")!) { _ in
      let current = WordsMediaCompanion.shared.snapshot["repeat"] as? String ?? "off"
      WordsMediaCompanion.shared.request("command", arguments: ["action":"repeat", "id":current == "off" ? "all" : current == "all" ? "one" : "off"]) { _ in }
    }
    repeatButton.isSelected = mode != "off"
    template.updateNowPlayingButtons([shuffle, repeatButton])
  }
  private func presentationFinished(_ success: Bool, _ error: Error?) {
    // CarPlay raises a native exception on failed presentation when its
    // completion is nil. A rejected template must never terminate audio.
    if let error = error { NSLog("Words CarPlay presentation: %@", error.localizedDescription) }
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
  private func loadFolder(_ id: String, title: String, template: CPListTemplate, connection: UUID) {
    WordsMediaCompanion.shared.request("children", arguments: ["id": id]) { [weak self, weak template] value in
      guard let self = self, let template = template,
            self.connection == connection, self.controller != nil else { return }
      if let failure = value as? [String: Any], let error = failure["error"] as? String {
        let retry = CPListItem(text: self.text("Retry", "重试", "重試"), detailText: error, image: UIImage(systemName: "arrow.clockwise"))
        retry.handler = { [weak self, weak template] _, complete in
          complete()
          guard let template = template, self?.connection == connection else { return }
          template.updateSections([])
          self?.loadFolder(id, title: title, template: template, connection: connection)
        }
        template.updateSections([CPListSection(items: [retry])])
        return
      }
      let records = value as? [[String: Any]] ?? []
      let rows = records.prefix(CPListTemplate.maximumItemCount).map { row -> CPListItem in
        let key = row["id"] as? String ?? ""
        let playable = row["playable"] as? Bool ?? false
        let symbol = key.contains("sermon") || key.contains("topic") ? "waveform" : key.contains("instrumental") ? "pianokeys" : "music.note"
        let image = UIImage(systemName: symbol)?.withTintColor(UIColor(red: 0.33, green: 0.78, blue: 0.96, alpha: 1), renderingMode: .alwaysOriginal)
        let item = CPListItem(text: row["title"] as? String ?? self.text("Audio", "音频", "音訊"),
                              detailText: row["subtitle"] as? String, image: image)
        item.accessoryType = playable ? .none : .disclosureIndicator
        item.handler = { [weak self] _, complete in
          guard self?.connection == connection else { complete(); return }
          if playable {
            WordsMediaCompanion.shared.request("command", arguments: ["action": "select", "id": key]) { [weak self] result in
              complete()
              guard let self = self, self.connection == connection, let controller = self.controller else { return }
              if let error = (result as? [String: Any])?["error"] as? String, !error.isEmpty {
                self.showError(error)
              } else if controller.topTemplate !== CPNowPlayingTemplate.shared {
                CPNowPlayingTemplate.shared.upNextTitle = self.text("Playing queue", "播放队列", "播放佇列")
                controller.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: self.presentationFinished)
              }
            }
          } else { self?.showFolder(key, title: row["title"] as? String ?? title); complete() }
        }
        return item
      }
      template.emptyViewTitleVariants = [self.text("No audio available", "暂无音频", "暫無音訊")]
      template.emptyViewSubtitleVariants = [self.text("Choose another category.", "请选择其他分类。", "請選擇其他分類。")]
      template.updateSections([CPListSection(items: rows)])
    }
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
