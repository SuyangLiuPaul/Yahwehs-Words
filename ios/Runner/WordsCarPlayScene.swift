#if CARPLAY_ENABLED
import CarPlay
import Flutter
import UIKit

/// The granted phone and dashboard scenes share one playback engine.
@available(iOS 14.0, *)
class WordsCarPlayScene: UIResponder, CPTemplateApplicationSceneDelegate {
  private var controller: CPInterfaceController?
  private var connection: UUID?
  func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                didConnect interfaceController: CPInterfaceController) {
    controller = interfaceController
    connection = UUID()
    (UIApplication.shared.delegate as? AppDelegate)?.ensureMediaEngine()
    showFolder("car:root", title: "Yahweh’s Words", root: true)
  }
  func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                didDisconnect interfaceController: CPInterfaceController) {
    connection = nil
    controller = nil // The phone's existing audio session keeps playing.
  }
  private func presentationFinished(_ success: Bool, _ error: Error?) {
    // CarPlay raises a native exception on failed presentation when its
    // completion is nil. A rejected template must never terminate audio.
    if let error = error { NSLog("Words CarPlay presentation: %@", error.localizedDescription) }
  }
  private func showFolder(_ id: String, title: String, root: Bool = false) {
    guard let controller = controller, let connection = connection else { return }
    let template = CPListTemplate(title: title, sections: [])
    template.emptyViewTitleVariants = ["Loading audio…"]
    template.emptyViewSubtitleVariants = ["Connecting to your library"]
    if root { controller.setRootTemplate(template, animated: false, completion: presentationFinished) }
    else { controller.pushTemplate(template, animated: true, completion: presentationFinished) }
    loadFolder(id, title: title, template: template, connection: connection)
  }
  private func loadFolder(_ id: String, title: String, template: CPListTemplate, connection: UUID) {
    WordsMediaCompanion.shared.request("children", arguments: ["id": id]) { [weak self, weak template] value in
      guard let self = self, let template = template,
            self.connection == connection, self.controller != nil else { return }
      if let failure = value as? [String: Any], let error = failure["error"] as? String {
        let retry = CPListItem(text: "Retry · 重试", detailText: error)
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
        let item = CPListItem(text: row["title"] as? String ?? "Audio",
                              detailText: row["subtitle"] as? String)
        let key = row["id"] as? String ?? ""
        let playable = row["playable"] as? Bool ?? false
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
                controller.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: self.presentationFinished)
              }
            }
          } else { self?.showFolder(key, title: row["title"] as? String ?? title); complete() }
        }
        return item
      }
      template.emptyViewTitleVariants = ["No audio available"]
      template.emptyViewSubtitleVariants = ["Choose another category."]
      template.updateSections([CPListSection(items: rows)])
    }
  }
  private func showError(_ message: String) {
    guard let controller = controller else { return }
    let close = CPAlertAction(title: "OK", style: .default) { [weak self] _ in
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
