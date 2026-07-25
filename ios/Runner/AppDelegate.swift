import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // FCM on iOS can't mint a token until Apple delivers the APNs device token,
    // which only happens after the app explicitly registers for remote
    // notifications. Without this call the APNs token never arrives and
    // getToken() throws "APNS token has not been set yet". (Mirrors the working
    // Tamweeniya-Agent setup.)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate =
        self as? UNUserNotificationCenterDelegate
    }
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
