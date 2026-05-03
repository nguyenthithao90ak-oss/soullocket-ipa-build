import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let widgetBridgeChannelName = "soullocket/widget_ios_bridge"
  private let bootstrapChannelName = "soul_locket/bootstrap"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: widgetBridgeChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(
            FlutterError(
              code: "bridge_unavailable",
              message: "App delegate bridge is unavailable.",
              details: nil
            )
          )
          return
        }
        self.handleWidgetBridge(call: call, result: result)
      }

      let bootstrapChannel = FlutterMethodChannel(
        name: bootstrapChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      bootstrapChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(
            FlutterError(
              code: "bootstrap_unavailable",
              message: "App delegate bootstrap is unavailable.",
              details: nil
            )
          )
          return
        }
        self.handleBootstrap(call: call, result: result)
      }
      let appControlChannel = FlutterMethodChannel(
        name: "soul_locket/app_control",
        binaryMessenger: controller.binaryMessenger
      )
      appControlChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(FlutterError(code: "unavailable", message: nil, details: nil))
          return
        }
        self.handleAppControl(call: call, result: result)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleAppControl(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setAppIcon":
      guard let args = call.arguments as? [String: Any],
            let iconKey = args["iconKey"] as? String else {
        result(false)
        return
      }
      let name: String? = (iconKey.lowercased() == "rose") ? nil : iconKey.lowercased()
      if UIApplication.shared.supportsAlternateIcons {
        UIApplication.shared.setAlternateIconName(name) { error in
          result(error == nil)
        }
      } else {
        result(false)
      }
    case "getCurrentAppIcon":
      let current = UIApplication.shared.alternateIconName ?? "rose"
      result(current)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleBootstrap(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getAppSignatureStatus":
      result([
        "status": "ok",
        "reasonCode": "ios_bundle",
        "isTrusted": true,
      ])
    case "getNativeFirebaseOptions":
      result(loadFirebaseOptions())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func loadFirebaseOptions() -> [String: String]? {
    guard
      let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
      let plist = NSDictionary(contentsOfFile: path) as? [String: Any]
    else {
      return nil
    }

    func read(_ key: String) -> String {
      return (plist[key] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    let apiKey = read("API_KEY")
    let appId = read("GOOGLE_APP_ID")
    let messagingSenderId = read("GCM_SENDER_ID")
    let projectId = read("PROJECT_ID")

    if apiKey.isEmpty || appId.isEmpty || messagingSenderId.isEmpty || projectId.isEmpty {
      return nil
    }

    return [
      "apiKey": apiKey,
      "appId": appId,
      "messagingSenderId": messagingSenderId,
      "projectId": projectId,
      "databaseURL": read("DATABASE_URL"),
      "storageBucket": read("STORAGE_BUCKET"),
      "iosBundleId": read("BUNDLE_ID"),
    ]
  }

  private func handleWidgetBridge(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "copyFileToAppGroup":
      copyFileToAppGroup(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func copyFileToAppGroup(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let groupId = args["groupId"] as? String,
      let sourcePath = args["sourcePath"] as? String,
      let fileName = args["fileName"] as? String
    else {
      result(
        FlutterError(
          code: "invalid_args",
          message: "copyFileToAppGroup requires groupId, sourcePath, and fileName.",
          details: nil
        )
      )
      return
    }

    let fileManager = FileManager.default
    let sourceURL = URL(fileURLWithPath: sourcePath)

    guard fileManager.fileExists(atPath: sourceURL.path) else {
      result(
        FlutterError(
          code: "source_missing",
          message: "Source file does not exist.",
          details: sourcePath
        )
      )
      return
    }

    guard
      let containerURL = fileManager.containerURL(
        forSecurityApplicationGroupIdentifier: groupId
      )
    else {
      result(
        FlutterError(
          code: "container_unavailable",
          message: "Unable to resolve the App Group container.",
          details: groupId
        )
      )
      return
    }

    let widgetAssetsURL = containerURL.appendingPathComponent(
      "widget_assets",
      isDirectory: true
    )
    let destinationURL = widgetAssetsURL.appendingPathComponent(fileName, isDirectory: false)

    do {
      try fileManager.createDirectory(
        at: widgetAssetsURL,
        withIntermediateDirectories: true
      )
      if fileManager.fileExists(atPath: destinationURL.path) {
        try fileManager.removeItem(at: destinationURL)
      }
      try fileManager.copyItem(at: sourceURL, to: destinationURL)
      result(destinationURL.path)
    } catch {
      result(
        FlutterError(
          code: "copy_failed",
          message: "Failed to copy asset into the App Group container.",
          details: error.localizedDescription
        )
      )
    }
  }
}
