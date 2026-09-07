import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    applySavedTheme()
    registerThemeChannel()
    return ok
  }

  private func registerThemeChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "givechain/theme",
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setNightMode" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let args = call.arguments as? [String: Any]
      self?.applyThemeMode(args?["mode"] as? String)
      result(nil)
    }
  }

  private func applySavedTheme() {
    let mode = UserDefaults.standard.string(forKey: "flutter.givechain_theme_mode")
    applyThemeMode(mode)
  }

  private func applyThemeMode(_ mode: String?) {
    let style: UIUserInterfaceStyle
    switch mode {
    case "light":
      style = .light
    case "dark":
      style = .dark
    default:
      style = .unspecified
    }

    window?.overrideUserInterfaceStyle = style
    if #available(iOS 13.0, *) {
      for scene in UIApplication.shared.connectedScenes {
        guard let windowScene = scene as? UIWindowScene else { continue }
        for sceneWindow in windowScene.windows {
          sceneWindow.overrideUserInterfaceStyle = style
        }
      }
    }
  }
}
