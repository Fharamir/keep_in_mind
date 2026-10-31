import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let appGroupId = "group.dev.fharamir.keepinmind"
  private let widgetKey = "widget_payload_json"
  private let sharedInboxKey = "shared_inbox_payload"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()

    let shareChannel = FlutterMethodChannel(
      name: "dev.fharamir.keepinmind/share",
      binaryMessenger: messenger
    )
    shareChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      if call.method == "getInitialSharedPayload" {
        let defaults = UserDefaults(suiteName: self.appGroupId)
        if let payload = defaults?.dictionary(forKey: self.sharedInboxKey) {
          defaults?.removeObject(forKey: self.sharedInboxKey)
          result(payload)
        } else {
          result(nil)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    let widgetChannel = FlutterMethodChannel(
      name: "dev.fharamir.keepinmind/widget",
      binaryMessenger: messenger
    )
    widgetChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      if call.method == "updateWidget" {
        if let args = call.arguments as? [String: Any],
           let json = args["payloadJson"] as? String {
          let defaults = UserDefaults(suiteName: self.appGroupId)
          defaults?.set(json, forKey: self.widgetKey)
        }
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

