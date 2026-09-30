#if CARPLAY_ENABLED
import CarPlay
import Flutter
import UIKit

/// Compiled only after Apple's granted audio entitlement has been
/// verified by tools/configure_carplay.py. Both scenes share one engine
/// so a cold launch from the dashboard works without touching iPhone.
@available(iOS 14.0, *)
class WordsCarPlayScene: UIResponder, CPTemplateApplicationSceneDelegate {
  private var controller: CPInterfaceController?
  func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                didConnect interfaceController: CPInterfaceController) {
    controller = interfaceController
    (UIApplication.shared.delegate as? AppDelegate)?.ensureMediaEngine()
    showFolder("car:root", title: "Yahweh’s Words", root: true)
  }
  func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                didDisconnect interfaceController: CPInterfaceController) {
    controller = nil // Audio continues through the existing media session.
  }
  private func showFolder(_ id: String, title: String, root: Bool = false) {
    let loading = CPListTemplate(title: title, sections: [])
    loading.emptyViewTitleVariants = ["Loading audio…"]
    loading.emptyViewSubtitleVariants = ["Connecting to your library"]
    if root { controller?.setRootTemplate(loading, animated: false, completion: nil) }
    else { controller?.pushTemplate(loading, animated: true, completion: nil) }
    WordsMediaCompanion.shared.request("children", arguments: ["id": id]) { [weak self, weak loading] value in
      guard let self = self, let template = loading, self.controller != nil else { return }
      let records = value as? [[String: Any]] ?? []
      let rows = records.prefix(CPListTemplate.maximumItemCount).map { row -> CPListItem in
        let item = CPListItem(text: row["title"] as? String ?? "Audio",
                              detailText: row["subtitle"] as? String)
        let key = row["id"] as? String ?? ""
        let playable = row["playable"] as? Bool ?? false
        item.accessoryType = playable ? .none : .disclosureIndicator
        item.handler = { [weak self] _, complete in
          if playable {
            WordsMediaCompanion.shared.request("command", arguments: ["action": "select", "id": key]) { result in
              complete()
              if let error = (result as? [String: Any])?["error"] as? String, !error.isEmpty {
                self?.showError(error)
              } else { self?.controller?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil) }
            }
          } else { self?.showFolder(key, title: row["title"] as? String ?? title); complete() }
        }
        return item
      }
      template.emptyViewTitleVariants = ["Audio unavailable"]
      template.emptyViewSubtitleVariants = ["Check your connection and retry."]
      template.updateSections([CPListSection(items: rows)])
    }
  }
  private func showError(_ message: String) {
    let close = CPAlertAction(title: "OK", style: .default) { [weak self] _ in
      self?.controller?.dismissTemplate(animated: true, completion: nil)
    }
    controller?.presentTemplate(CPAlertTemplate(titleVariants: [message], actions: [close]), animated: true, completion: nil)
  }
}

class WordsPhoneScene: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
             options connectionOptions: UIScene.ConnectionOptions) {
    guard let windowScene = scene as? UIWindowScene,
          let app = UIApplication.shared.delegate as? AppDelegate else { return }
    let engine = app.ensureMediaEngine()
    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    self.window = window
    window.makeKeyAndVisible()
    // Cold phone URL and later scene URL events still reach Flutter.
    for context in connectionOptions.urlContexts { _ = app.application(UIApplication.shared, open: context.url, options: [:]) }
  }
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let app = UIApplication.shared.delegate as? AppDelegate else { return }
    for context in URLContexts { _ = app.application(UIApplication.shared, open: context.url, options: [:]) }
  }
}
#endif
