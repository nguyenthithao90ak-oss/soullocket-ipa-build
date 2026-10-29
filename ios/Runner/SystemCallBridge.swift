import Flutter
import UIKit
import CallKit
import PushKit
import UserNotifications
import AVFAudio
import CryptoKit
import FirebaseCore
import FirebaseAuth
import FirebaseDatabase
#if canImport(WebRTC)
import WebRTC
#endif

/// Provider sống cùng app; CallKit sở hữu chuông, WebRTC sở hữu media.
final class SystemCallBridge: NSObject, CXProviderDelegate, PKPushRegistryDelegate {
  static let shared = SystemCallBridge()
  private let provider: CXProvider
  private let controller = CXCallController()
  private var registry: PKPushRegistry?
  private var channel: FlutterMethodChannel?
  private var pending: [[String: Any]] = []
  private var active: Call?
  private var voipToken: String?
  private let defaults = UserDefaults.standard

  private final class Call {
    let id: UUID
    let room: String
    var data: [String: Any]
    var timer: Timer?
    var statusRef: DatabaseReference?
    var statusHandle: DatabaseHandle?
    var answerAction: CXAnswerCallAction?
    var answerRequested = false
    var answerEmitted = false
    var verified = false
    var reported = false
    var ready = false
    var muted = false
    var audioManaged = false
    var deadline: TimeInterval = 0
    init(id: UUID, room: String, data: [String: Any]) {
      self.id = id; self.room = room; self.data = data
    }
  }

  private override init() {
    let configuration = CXProviderConfiguration(localizedName: "SoulLocket")
    configuration.supportsVideo = true
    configuration.maximumCallGroups = 1
    configuration.maximumCallsPerCallGroup = 1
    configuration.supportedHandleTypes = [.generic]
    configuration.includesCallsInRecents = false
    configuration.ringtoneSound = "soul_call_ringtone.wav"
    provider = CXProvider(configuration: configuration)
    super.init()
    provider.setDelegate(self, queue: .main)
  }

  func start() {
    guard defaults.bool(forKey: "soul_call_enabled"),
          defaults.string(forKey: "soul_call_uid") != nil else { return }
    if registry == nil {
      registry = PKPushRegistry(queue: .main)
      registry?.delegate = self
    }
    registry?.desiredPushTypes = [.voIP]
  }

  func attach(messenger: FlutterBinaryMessenger) {
    channel?.setMethodCallHandler(nil)
    channel = FlutterMethodChannel(name: "soullocket/system_calls", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] method, result in
      guard let self = self else { result(nil); return }
      let args = method.arguments as? [String: Any] ?? [:]
      let room = args["roomId"] as? String ?? ""
      switch method.method {
      case "configure":
        let uid = args["uid"] as? String
        let enabled = args["enabled"] as? Bool == true && !(uid?.isEmpty ?? true)
        let changed = self.defaults.string(forKey: "soul_call_uid") != uid ||
          self.defaults.bool(forKey: "soul_call_enabled") != enabled
        if self.defaults.string(forKey: "soul_call_uid") != uid {
          if let call = self.active { self.finish(call, reason: .failed) }
          self.pending.removeAll()
        } else if !enabled, let call = self.active, !call.answerRequested {
          self.finish(call, reason: .unanswered)
        }
        self.defaults.set(uid, forKey: "soul_call_uid")
        self.defaults.set(enabled, forKey: "soul_call_enabled")
        if enabled { self.start() } else { self.registry?.desiredPushTypes = [] }
        result(nil)
        if changed { self.channel?.invokeMethod("onRegistrationChanged", arguments: nil) }
      case "registration":
        var registration: [String: Any] = ["callUiVersion": 1]
        if self.defaults.bool(forKey: "soul_call_enabled"),
           let token = self.voipToken ?? self.registry?.pushToken(for: .voIP)?.map({ String(format: "%02x", $0) }).joined() {
          registration["voipToken"] = token
          #if DEBUG
          registration["apnsEnvironment"] = "sandbox"
          #else
          registration["apnsEnvironment"] = "production"
          #endif
        }
        result(registration)
      case "hasTimeSensitiveNotificationAccess":
        if #available(iOS 15.0, *) {
          UNUserNotificationCenter.current().getNotificationSettings { settings in
            let authorized = settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional
            let enabled = authorized && settings.timeSensitiveSetting == .enabled
            DispatchQueue.main.async { result(enabled) }
          }
        } else {
          result(false)
        }
      case "takePending":
        let events = self.pending; self.pending.removeAll(); result(events)
      case "reportIncoming":
        self.report(args, fromPush: false) { shown in result(shown) }
      case "answer":
        guard let call = self.active, call.room == room, !call.answerRequested else { result(nil); return }
        self.controller.request(CXTransaction(action: CXAnswerCallAction(call: call.id))) { error in
          DispatchQueue.main.async {
            if error != nil, self.active === call { self.finish(call, reason: .failed) }
            result(nil)
          }
        }
      case "mediaReady":
        if let call = self.active, call.room == room {
          call.ready = true
          self.completeAnswerIfReady(call)
        }
        result(nil)
      case "end":
        if let call = self.active, call.room == room { self.finish(call, reason: .remoteEnded) }
        result(nil)
      case "setMuted":
        if let call = self.active, call.room == room, let muted = args["muted"] as? Bool,
           call.muted != muted {
          self.controller.request(CXTransaction(action: CXSetMutedCallAction(call: call.id, muted: muted))) { _ in }
        }
        result(nil)
      case "setIncomingVisible": result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func emit(_ call: Call, action: String, extra: [String: Any] = [:]) {
    var event = call.data
    event["screen"] = "soul_merge_call"; event["callAction"] = action
    for (key, value) in extra { event[key] = value }
    if action == "end" || action == "decline" {
      pending.removeAll { ($0["roomId"] as? String) == call.room }
    } else {
      pending.removeAll { ($0["roomId"] as? String) == call.room && ($0["callAction"] as? String) == action }
    }
    pending.append(event)
    if pending.count > 8 { pending.removeFirst(pending.count - 8) }
    channel?.invokeMethod("onCallEvent", arguments: event)
  }

  private func identifier(_ room: String) -> UUID {
    let bytes = Array(SHA256.hash(data: Data(room.utf8)).prefix(16))
    return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
      bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
  }

  private func report(_ payload: [String: Any], fromPush: Bool, completion: @escaping (Bool) -> Void) {
    let room = payload["roomId"] as? String ?? ""
    if let call = active, call.room == room,
       call.data["accountUid"] as? String == payload["accountUid"] as? String {
      completion(true); return
    }
    let validRoom = room.range(of: "^[A-Za-z0-9_-]{1,260}$", options: .regularExpression) != nil
    let uid = defaults.string(forKey: "soul_call_uid")
    let scoped = validRoom && defaults.bool(forKey: "soul_call_enabled") && uid != nil &&
      (payload["accountUid"] as? String) == uid && active == nil
    if !fromPush && !scoped { completion(false); return }
    let update = CXCallUpdate()
    let name = String((payload["callerName"] as? String ?? "SoulLocket").prefix(120))
    update.remoteHandle = CXHandle(type: .generic, value: name.isEmpty ? "SoulLocket" : name)
    update.localizedCallerName = name
    update.hasVideo = (payload["isVideo"] as? Bool == true) || (payload["isVideo"] as? String == "true")
    update.supportsHolding = false; update.supportsGrouping = false; update.supportsUngrouping = false
    let call = Call(id: validRoom ? identifier(room) : UUID(), room: room, data: payload)
    // Giữ reservation ngay trước report để FCM/RTDB/PushKit không report trùng.
    if scoped { active = call }
    provider.reportNewIncomingCall(with: call.id, update: update) { [weak self] error in
      DispatchQueue.main.async {
        guard let self = self else { completion(false); return }
        guard error == nil else {
          if self.active === call { self.active = nil }
          completion(false); return
        }
        call.reported = true
        guard scoped, self.active === call,
              self.defaults.string(forKey: "soul_call_uid") == uid,
              self.defaults.bool(forKey: "soul_call_enabled") else {
          self.provider.reportCall(with: call.id, endedAt: Date(), reason: .failed)
          completion(false); return
        }
        self.arm(call, seconds: 45, reason: .unanswered)
        self.verify(call, attempt: 0)
        completion(true)
      }
    }
  }

  private func arm(_ call: Call, seconds: TimeInterval, reason: CXCallEndedReason) {
    call.timer?.invalidate()
    call.timer = Timer.scheduledTimer(withTimeInterval: max(0.05, min(45, seconds)), repeats: false) { [weak self, weak call] _ in
      guard let self = self, let call = call, self.active === call else { return }
      self.emit(call, action: "end"); self.finish(call, reason: reason)
    }
  }

  private func reject(_ call: Call, reason: CXCallEndedReason = .failed) {
    guard active === call else { return }
    emit(call, action: "end"); finish(call, reason: reason)
  }

  private func verify(_ call: Call, attempt: Int) {
    guard active === call else { return }
    guard FirebaseApp.app() != nil, let user = Auth.auth().currentUser else {
      if attempt >= 20 { reject(call); return }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak call] in
        if let self = self, let call = call { self.verify(call, attempt: attempt + 1) }
      }
      return
    }
    guard user.uid == (call.data["accountUid"] as? String) else { reject(call); return }
    let root = Database.database().reference()
    root.child("users").child(user.uid).child("houseId").observeSingleEvent(of: .value, with: { [weak self, weak call] snapshot in
      guard let self = self, let call = call, self.active === call else { return }
      if let house = snapshot.value as? String, !house.isEmpty {
        self.verifyRoom(call, house: house)
      } else {
        root.child("users").child(user.uid).child("house_id").observeSingleEvent(of: .value, with: { [weak self, weak call] legacy in
          guard let self = self, let call = call, self.active === call else { return }
          guard let house = legacy.value as? String, !house.isEmpty else { self.reject(call); return }
          self.verifyRoom(call, house: house)
        }, withCancel: { [weak self, weak call] _ in
          if let self = self, let call = call { self.reject(call) }
        })
      }
    }, withCancel: { [weak self, weak call] _ in
      if let self = self, let call = call { self.reject(call) }
    })
  }

  private func verifyRoom(_ call: Call, house: String) {
    guard active === call, house == (call.data["houseId"] as? String),
          Auth.auth().currentUser?.uid == (call.data["accountUid"] as? String) else { reject(call); return }
    let root = Database.database().reference()
    Database.database().reference(withPath: ".info/serverTimeOffset").observeSingleEvent(of: .value, with: { [weak self, weak call] offsetSnapshot in
      guard let self = self, let call = call, self.active === call else { return }
      let offset = (offsetSnapshot.value as? NSNumber)?.doubleValue ?? 0
      let ref = root.child("calls").child(call.room)
      ref.observeSingleEvent(of: .value, with: { [weak self, weak call] snapshot in
        guard let self = self, let call = call, self.active === call else { return }
        let now = Date().timeIntervalSince1970 * 1000
        guard Auth.auth().currentUser?.uid == (call.data["accountUid"] as? String),
              let data = snapshot.value as? [String: Any], data["status"] as? String == "ringing",
              data["calleeId"] as? String == house,
              let caller = data["callerId"] as? String, !caller.isEmpty,
              caller != Auth.auth().currentUser?.uid,
              let timestamp = (data["timestamp"] as? NSNumber)?.doubleValue, timestamp.isFinite, timestamp > 0,
              timestamp > now + offset - 45000, timestamp <= now + offset + 30000 else { self.reject(call); return }
        let remaining = min(45000, timestamp + 45000 - now - offset)
        call.deadline = ProcessInfo.processInfo.systemUptime + remaining / 1000
        call.data["localExpiresAt"] = now + remaining
        call.data["timestamp"] = timestamp; call.data["callerId"] = caller
        call.data["callerHouseId"] = data["houseId"]
        call.verified = true
        call.statusRef = ref.child("status")
        call.statusHandle = call.statusRef?.observe(.value, with: { [weak self, weak call] statusSnapshot in
          guard let self = self, let call = call, self.active === call else { return }
          let status = statusSnapshot.value as? String
          if status == nil || status == "ended" || (status != "ringing" && !call.answerRequested) {
            self.reject(call, reason: .remoteEnded)
          }
        }, withCancel: { [weak self, weak call] _ in
          if let self = self, let call = call { self.reject(call) }
        })
        if call.answerRequested { self.emitAnswer(call); self.completeAnswerIfReady(call) }
        else { self.arm(call, seconds: remaining / 1000, reason: .unanswered) }
      }, withCancel: { [weak self, weak call] _ in
        if let self = self, let call = call { self.reject(call) }
      })
    }, withCancel: { [weak self, weak call] _ in
      if let self = self, let call = call { self.reject(call) }
    })
  }

  private func emitAnswer(_ call: Call) {
    guard active === call, call.verified, !call.answerEmitted,
          ProcessInfo.processInfo.systemUptime < call.deadline else { return }
    call.answerEmitted = true
    emit(call, action: "answer")
  }

  private func completeAnswerIfReady(_ call: Call) {
    guard active === call, call.ready, call.verified, call.answerRequested,
          let action = call.answerAction else { return }
    call.timer?.invalidate()
    action.fulfill(withDateConnected: Date()); call.answerAction = nil
    if call.muted { emit(call, action: "mute", extra: ["muted": true]) }
  }

  private func finish(_ call: Call, reason: CXCallEndedReason) {
    guard active === call else { return }
    active = nil
    call.timer?.invalidate(); call.answerAction?.fail(); call.answerAction = nil
    if let handle = call.statusHandle { call.statusRef?.removeObserver(withHandle: handle) }
    pending.removeAll { ($0["roomId"] as? String) == call.room && ($0["callAction"] as? String) == "answer" }
    if call.reported { provider.reportCall(with: call.id, endedAt: Date(), reason: reason) }
    #if canImport(WebRTC)
    if call.audioManaged { RTCAudioSession.sharedInstance().useManualAudio = false }
    #endif
  }

  private func persistDecline(_ call: Call) {
    guard FirebaseApp.app() != nil,
          Auth.auth().currentUser?.uid == (call.data["accountUid"] as? String) else { return }
    guard let uid = Auth.auth().currentUser?.uid else { return }
    let root = Database.database().reference()
    root.child("users").child(uid).child("houseId").observeSingleEvent(of: .value, with: { snapshot in
      guard let house = snapshot.value as? String, house == (call.data["houseId"] as? String),
            Auth.auth().currentUser?.uid == uid else { return }
      Database.database().reference(withPath: ".info/serverTimeOffset").observeSingleEvent(of: .value, with: { offsetSnapshot in
        let offset = (offsetSnapshot.value as? NSNumber)?.doubleValue ?? 0
        root.child("calls").child(call.room).runTransactionBlock({ current in
      if current.value == nil || current.value is NSNull { return TransactionResult.success(withValue: current) }
      guard Auth.auth().currentUser?.uid == uid, var value = current.value as? [String: Any],
            value["status"] as? String == "ringing",
            let caller = value["callerId"] as? String, caller != uid,
            value["calleeId"] as? String == house,
            let timestamp = (value["timestamp"] as? NSNumber)?.doubleValue, timestamp.isFinite,
            timestamp > Date().timeIntervalSince1970 * 1000 + offset - 45000,
            timestamp <= Date().timeIntervalSince1970 * 1000 + offset + 30000 else { return TransactionResult.abort() }
      if call.verified && ((value["timestamp"] as? NSNumber) != (call.data["timestamp"] as? NSNumber) ||
          caller != (call.data["callerId"] as? String)) { return TransactionResult.abort() }
      value["status"] = "ended"; value["endReason"] = "declined"; value["endedAt"] = ServerValue.timestamp()
      current.value = value
      return TransactionResult.success(withValue: current)
    }, andCompletionBlock: { _, _, _ in }, withLocalEvents: false)
      })
    })
  }

  func providerDidReset(_ provider: CXProvider) {
    if let call = active { reject(call) }
  }

  func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    guard let call = active, call.id == action.callUUID, !call.answerRequested else { action.fail(); return }
    call.answerRequested = true; call.answerAction = action
    arm(call, seconds: 30, reason: .failed)
    #if canImport(WebRTC)
    call.audioManaged = true
    RTCAudioSession.sharedInstance().useManualAudio = true
    RTCAudioSession.sharedInstance().isAudioEnabled = false
    #endif
    if call.verified { emitAnswer(call); completeAnswerIfReady(call) }
  }

  func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    guard let call = active, call.id == action.callUUID else { action.fulfill(); return }
    persistDecline(call) // Nếu WebRTC chưa nối, native vẫn đóng ringing khi Flutter chưa sẵn sàng.
    emit(call, action: call.answerRequested ? "end" : "decline")
    finish(call, reason: .remoteEnded); action.fulfill()
  }

  func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
    guard let call = active, call.id == action.callUUID else { action.fail(); return }
    call.muted = action.isMuted
    emit(call, action: "mute", extra: ["muted": action.isMuted]); action.fulfill()
  }

  func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
    if let call = active, let callAction = action as? CXCallAction,
       call.id == callAction.callUUID { reject(call) }
  }

  func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    #if canImport(WebRTC)
    guard active?.audioManaged == true else { return }
    RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
    RTCAudioSession.sharedInstance().isAudioEnabled = true
    #endif
  }

  func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
    #if canImport(WebRTC)
    RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
    #endif
  }

  func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
    guard type == .voIP else { return }
    voipToken = credentials.token.map { String(format: "%02x", $0) }.joined()
    channel?.invokeMethod("onRegistrationChanged", arguments: nil)
  }
  func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
    if type == .voIP { voipToken = nil; channel?.invokeMethod("onRegistrationChanged", arguments: nil) }
  }
  func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType, completion: @escaping () -> Void) {
    guard type == .voIP else { completion(); return }
    let data = payload.dictionaryPayload.reduce(into: [String: Any]()) { result, item in
      if let key = item.key as? String { result[key] = item.value }
    }
    // Apple yêu cầu report ngay trong callback; không đợi Firebase/network.
    report(data, fromPush: true) { _ in completion() }
  }
}
