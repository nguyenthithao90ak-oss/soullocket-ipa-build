import Flutter
import UIKit
#if canImport(ActivityKit)
import ActivityKit
#endif

import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let widgetBridgeChannelName = "soullocket/widget_ios_bridge"
  private let bootstrapChannelName = "soul_locket/bootstrap"
  private let appIconChannelName = "soullocket/app_icon"
  private let deviceInfoChannelName = "soul_locket/device_info"
  private let attPrePromptChannelName = "soullocket/att_pre_prompt"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY_HERE")
    GeneratedPluginRegistrant.register(with: self)
    
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }

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

      let appIconChannel = FlutterMethodChannel(
        name: appIconChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      appIconChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(
            FlutterError(
              code: "app_icon_unavailable",
              message: "App icon bridge is unavailable.",
              details: nil
            )
          )
          return
        }
        self.handleAppIcon(call: call, result: result)
      }

      let deviceInfoChannel = FlutterMethodChannel(
        name: deviceInfoChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      deviceInfoChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "getBatteryInfo":
          UIDevice.current.isBatteryMonitoringEnabled = true
          let level = UIDevice.current.batteryLevel
          let state = UIDevice.current.batteryState
          let isCharging = state == .charging || state == .full
          let pct = level >= 0 ? Int(level * 100) : -1
          result(["level": pct, "isCharging": isCharging])
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      let attPrePromptChannel = FlutterMethodChannel(
        name: attPrePromptChannelName,
        binaryMessenger: controller.binaryMessenger
      )
      attPrePromptChannel.setMethodCallHandler { [weak self] call, result in
        guard let self = self else {
          result(false)
          return
        }
        self.handleAttPrePrompt(call: call, result: result)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - ATT Pre-Prompt (Apple guideline: explain before asking to track)

  private func handleAttPrePrompt(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "showPreAttPrompt":
      showAttPrePromptAlert(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func showAttPrePromptAlert(result: @escaping FlutterResult) {
    guard let controller = window?.rootViewController else {
      // Nếu không có view controller, cho phép ATT prompt hiện lên
      result(true)
      return
    }

    let alert = UIAlertController(
      title: "Cá nhân hóa trải nghiệm",
      message: "SoulLocket muốn theo dõi hoạt động của bạn để hiển thị quảng cáo phù hợp hơn và đo lường hiệu quả chiến dịch. Bạn có thể thay đổi lựa chọn này bất cứ lúc nào trong Cài đặt.",
      preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(
      title: "Tiếp tục",
      style: .default,
      handler: { _ in result(true) }
    ))

    alert.addAction(UIAlertAction(
      title: "Không",
      style: .cancel,
      handler: { _ in result(false) }
    ))

    controller.present(alert, animated: true, completion: nil)
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

  private func handleAppIcon(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setAlternateIconName":
      setAlternateIconName(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func setAlternateIconName(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(
        FlutterError(
          code: "invalid_args",
          message: "setAlternateIconName requires arguments.",
          details: nil
        )
      )
      return
    }

    guard UIApplication.shared.supportsAlternateIcons else {
      result(
        FlutterError(
          code: "unsupported",
          message: "Alternate app icons are not supported on this device.",
          details: nil
        )
      )
      return
    }

    let requestedIconName = (args["iconName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let iconName = (requestedIconName?.isEmpty ?? true) ? nil : requestedIconName

    UIApplication.shared.setAlternateIconName(iconName) { error in
      if let error = error {
        result(
          FlutterError(
            code: "set_icon_failed",
            message: "Failed to change alternate app icon.",
            details: error.localizedDescription
          )
        )
      } else {
        result(nil)
      }
    }
  }

  private func handleWidgetBridge(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "copyFileToAppGroup":
      copyFileToAppGroup(call: call, result: result)
    case "startLiveActivity":
      startLiveActivity(call: call, result: result)
    case "updateLiveActivity":
      updateLiveActivity(call: call, result: result)
    case "endLiveActivity":
      endLiveActivity(call: call, result: result)
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

  private func startLiveActivity(call: FlutterMethodCall, result: @escaping FlutterResult) {
    #if canImport(ActivityKit)
    if #available(iOS 16.1, *) {
      guard let args = call.arguments as? [String: Any],
            let title = args["title"] as? String,
            let label = args["label"] as? String,
            let endTimeMs = args["endTimeMs"] as? Double else {
        result(
          FlutterError(
            code: "invalid_args",
            message: "startLiveActivity requires title, label, and endTimeMs.",
            details: nil
          )
        )
        return
      }

      for activity in Activity<SoulLocketActivityAttributes>.activities {
        Task {
          await activity.end(dismissalPolicy: .immediate)
        }
      }

      let attributes = SoulLocketActivityAttributes(title: title)
      let endTime = Date(timeIntervalSince1970: endTimeMs / 1000.0)
      let initialContentState = SoulLocketActivityAttributes.ContentState(endTime: endTime, label: label)

      do {
        let activity = try Activity<SoulLocketActivityAttributes>.request(
          attributes: attributes,
          contentState: initialContentState,
          pushType: nil
        )
        result(activity.id)
      } catch {
        result(
          FlutterError(
            code: "start_failed",
            message: "Failed to start live activity: \(error.localizedDescription)",
            details: nil
          )
        )
      }
    } else {
      result(
        FlutterError(
          code: "unsupported",
          message: "Live Activities require iOS 16.1 or later.",
          details: nil
        )
      )
    }
    #else
    result(
      FlutterError(
        code: "unsupported",
        message: "ActivityKit is not available on this platform compilation.",
        details: nil
      )
    )
    #endif
  }

  private func updateLiveActivity(call: FlutterMethodCall, result: @escaping FlutterResult) {
    #if canImport(ActivityKit)
    if #available(iOS 16.1, *) {
      guard let args = call.arguments as? [String: Any],
            let activityId = args["activityId"] as? String,
            let label = args["label"] as? String,
            let endTimeMs = args["endTimeMs"] as? Double else {
        result(
          FlutterError(
            code: "invalid_args",
            message: "updateLiveActivity requires activityId, label, and endTimeMs.",
            details: nil
          )
        )
        return
      }

      let endTime = Date(timeIntervalSince1970: endTimeMs / 1000.0)
      let contentState = SoulLocketActivityAttributes.ContentState(endTime: endTime, label: label)

      var found = false
      for activity in Activity<SoulLocketActivityAttributes>.activities {
        if activity.id == activityId {
          found = true
          Task {
            await activity.update(using: contentState)
            result(true)
          }
          break
        }
      }
      if !found {
        result(false)
      }
    } else {
      result(
        FlutterError(
          code: "unsupported",
          message: "Live Activities require iOS 16.1 or later.",
          details: nil
        )
      )
    }
    #else
    result(
      FlutterError(
        code: "unsupported",
        message: "ActivityKit is not available on this platform compilation.",
        details: nil
      )
    )
    #endif
  }

  private func endLiveActivity(call: FlutterMethodCall, result: @escaping FlutterResult) {
    #if canImport(ActivityKit)
    if #available(iOS 16.1, *) {
      guard let args = call.arguments as? [String: Any],
            let activityId = args["activityId"] as? String else {
        result(
          FlutterError(
            code: "invalid_args",
            message: "endLiveActivity requires activityId.",
            details: nil
          )
        )
        return
      }

      var found = false
      for activity in Activity<SoulLocketActivityAttributes>.activities {
        if activity.id == activityId {
          found = true
          Task {
            await activity.end(dismissalPolicy: .immediate)
            result(true)
          }
          break
        }
      }
      if !found {
        result(false)
      }
    } else {
      result(
        FlutterError(
          code: "unsupported",
          message: "Live Activities require iOS 16.1 or later.",
          details: nil
        )
      )
    }
    #else
    result(
      FlutterError(
        code: "unsupported",
        message: "ActivityKit is not available on this platform compilation.",
        details: nil
      )
    )
    #endif
  }
}

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
public struct SoulLocketActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var endTime: Date
        public var label: String
    }

    public var title: String

    public init(title: String) {
        self.title = title
    }
}
#endif

