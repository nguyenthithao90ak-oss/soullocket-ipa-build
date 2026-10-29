import Flutter
import UIKit
import Photos
import PhotosUI
import UniformTypeIdentifiers
import workmanager_apple
import flutter_local_notifications
#if canImport(ActivityKit)
import ActivityKit
#endif

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let widgetBridgeChannelName = "soullocket/widget_ios_bridge"
  private let bootstrapChannelName = "soul_locket/bootstrap"
  private let appIconChannelName = "soullocket/app_icon"
  private let deviceInfoChannelName = "soul_locket/device_info"
  private let attPrePromptChannelName = "soullocket/att_pre_prompt"
  private var callCameraEffectsBridge: CallCameraEffectsBridge?
  private var callToneBridge: CallToneBridge?
  private var memoryVideoEncoderBridge: MemoryVideoEncoderBridge?
  private var memoryMediaPicker: NSObject?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // BGTaskScheduler và delegate thông báo phải sẵn sàng trước khi launch kết thúc.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }
    WorkmanagerPlugin.registerPeriodicTask(withIdentifier: "com.soullocket.app.sleep.refresh", earliestBeginInSeconds: 1800)
    
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    SystemCallBridge.shared.start()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerNativeChannels(messenger: engineBridge.applicationRegistrar.messenger())
  }

  private func registerNativeChannels(messenger: FlutterBinaryMessenger) {
    SystemCallBridge.shared.attach(messenger: messenger)
    memoryVideoEncoderBridge?.dispose()
    memoryVideoEncoderBridge = MemoryVideoEncoderBridge(messenger: messenger)
    callCameraEffectsBridge = CallCameraEffectsBridge(messenger: messenger)
    callToneBridge?.dispose()
    callToneBridge = CallToneBridge(messenger: messenger)
    let memoryChannel = FlutterMethodChannel(
      name: "soullocket/memory_media_picker",
      binaryMessenger: messenger
    )
    memoryChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "pickMemoryMedia" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self = self, let presenter = self.foregroundPresenter() else {
        result(FlutterError(code: "picker_unavailable", message: nil, details: nil))
        return
      }
      guard self.memoryMediaPicker == nil else {
        result(FlutterError(code: "picker_busy", message: nil, details: nil))
        return
      }
      if #available(iOS 14.0, *) {
        let args = call.arguments as? [String: Any] ?? [:]
        let picker = MemoryMediaPickerCoordinator(
          limit: min(999, max(1, args["limit"] as? Int ?? 99)),
          preserveOriginal: args["preserveOriginal"] as? Bool ?? true
        ) { [weak self] value in
          self?.memoryMediaPicker = nil
          result(value)
        }
        self.memoryMediaPicker = picker
        picker.present(from: presenter)
      } else {
        result(FlutterError(code: "unsupported", message: nil, details: nil))
      }
    }
    let channel = FlutterMethodChannel(
      name: widgetBridgeChannelName,
      binaryMessenger: messenger
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
      binaryMessenger: messenger
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
      binaryMessenger: messenger
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
      binaryMessenger: messenger
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
      binaryMessenger: messenger
    )
    attPrePromptChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(false)
        return
      }
      self.handleAttPrePrompt(call: call, result: result)
    }
  }

  private func foregroundPresenter() -> UIViewController? {
    // UIWindow thuộc scene; AppDelegate.window có thể nil sau khi chuyển lifecycle.
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let scene = scenes.first { $0.activationState == .foregroundActive }
      ?? scenes.first { $0.activationState == .foregroundInactive }
    guard let root = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
      return nil
    }
    var presenter = root
    while let presented = presenter.presentedViewController {
      presenter = presented
    }
    return presenter
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
    guard let controller = foregroundPresenter() else {
      // Nếu không có view controller, cho phép ATT prompt hiện lên
      result(true)
      return
    }

    let alert = UIAlertController(
      title: NSLocalizedString("att_pre_prompt_title", tableName: "InfoPlist", comment: ""),
      message: NSLocalizedString("att_pre_prompt_body", tableName: "InfoPlist", comment: ""),
      preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(
      title: NSLocalizedString("att_pre_prompt_continue", tableName: "InfoPlist", comment: ""),
      style: .default,
      handler: { _ in result(true) }
    ))

    alert.addAction(UIAlertAction(
      title: NSLocalizedString("att_pre_prompt_decline", tableName: "InfoPlist", comment: ""),
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

// PHPicker chỉ cung cấp các mục người dùng chọn; không cần đọc toàn thư viện ảnh.
@available(iOS 14.0, *)
private final class MemoryMediaPickerCoordinator: NSObject, PHPickerViewControllerDelegate {
  private let limit: Int
  private let preserveOriginal: Bool
  private let completion: FlutterResult
  private var finished = false
  private var temporaryURLs: [URL] = []

  init(limit: Int, preserveOriginal: Bool, completion: @escaping FlutterResult) {
    self.limit = limit
    self.preserveOriginal = preserveOriginal
    self.completion = completion
    super.init()
  }

  func present(from presenter: UIViewController) {
    var configuration = PHPickerConfiguration()
    configuration.selectionLimit = limit
    configuration.filter = .any(of: [.images, .videos, .livePhotos])
    configuration.preferredAssetRepresentationMode = preserveOriginal ? .current : .compatible
    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    // Giữ callback hủy ở nút Cancel, tránh sheet bị vuốt tắt mà không trả result.
    picker.isModalInPresentation = true
    presenter.present(picker, animated: true)
  }

  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true) {
      self.load(results: Array(results.prefix(self.limit)), index: 0, entries: [])
    }
  }

  private func load(results: [PHPickerResult], index: Int, entries: [[String: String]]) {
    guard !finished else { return }
    guard index < results.count else {
      finish(entries)
      return
    }
    // Xuất tuần tự để không giữ hàng chục Live Photo/video trong RAM cùng lúc.
    export(provider: results[index].itemProvider) { entry in
      DispatchQueue.main.async {
        guard !self.finished else { return }
        guard let entry = entry else {
          for url in self.temporaryURLs { try? FileManager.default.removeItem(at: url) }
          self.finish(FlutterError(code: "media_export_failed", message: nil, details: nil))
          return
        }
        self.load(results: results, index: index + 1, entries: entries + [entry])
      }
    }
  }

  private func export(provider: NSItemProvider, completion: @escaping ([String: String]?) -> Void) {
    if provider.canLoadObject(ofClass: PHLivePhoto.self) {
      provider.loadObject(ofClass: PHLivePhoto.self) { object, error in
        guard error == nil, let livePhoto = object as? PHLivePhoto else {
          completion(nil)
          return
        }
        let resources = PHAssetResource.assetResources(for: livePhoto)
        guard let motion = resources.first(where: { $0.type == .fullSizePairedVideo })
          ?? resources.first(where: { $0.type == .pairedVideo }) else {
          completion(nil)
          return
        }
        let name = "live_photo_\(UUID().uuidString).mov"
        let target = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        PHAssetResourceManager.default().writeData(for: motion, toFile: target, options: options) { [livePhoto] error in
          // Giữ Live Photo sống tới khi xuất xong các resource của nó.
          _ = livePhoto
          DispatchQueue.main.async {
            self.temporaryURLs.append(target)
            completion(error == nil ? ["path": target.path, "name": name,
              "mimeType": "video/quicktime", "kind": "live_photo"] : nil)
          }
        }
      }
      return
    }
    let isVideo = provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
    let category = isVideo ? UTType.movie : UTType.image
    guard let identifier = provider.registeredTypeIdentifiers.first(where: {
      UTType($0)?.conforms(to: category) == true
    }) else {
      completion(nil)
      return
    }
    provider.loadFileRepresentation(forTypeIdentifier: identifier) { source, error in
      guard error == nil, let source = source else {
        completion(nil)
        return
      }
      let type = UTType(identifier)
      let ext = source.pathExtension.isEmpty
        ? (type?.preferredFilenameExtension ?? (isVideo ? "mov" : "jpg"))
        : source.pathExtension
      let name = "memory_\(UUID().uuidString).\(ext)"
      let target = FileManager.default.temporaryDirectory.appendingPathComponent(name)
      // URL nguồn hết hiệu lực khi callback kết thúc: phải copy ngay trong callback.
      do {
        try FileManager.default.copyItem(at: source, to: target)
        DispatchQueue.main.async {
          self.temporaryURLs.append(target)
          completion(["path": target.path, "name": name,
            "mimeType": UTType(filenameExtension: ext)?.preferredMIMEType
              ?? type?.preferredMIMEType ?? (isVideo ? "video/quicktime" : "image/jpeg"),
            "kind": isVideo ? "video" : "image"])
        }
      } catch {
        completion(nil)
      }
    }
  }

  private func finish(_ value: Any) {
    guard !finished else { return }
    finished = true
    completion(value)
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

