import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    guard let registrar = self.registrar(forPlugin: "HardwareServiceHandler") else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    HardwareServiceHandler.register(with: registrar)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
