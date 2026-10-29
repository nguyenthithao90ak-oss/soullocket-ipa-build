import AVFoundation
import Flutter

// Phát âm trong session do WebRTC quản lý, không thay category/route/active.
final class CallToneBridge: NSObject, AVAudioPlayerDelegate {
  private let channel: FlutterMethodChannel
  private var player: AVAudioPlayer?
  private var owner: String?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "soullocket/call_tones", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      let args = call.arguments as? [String: Any] ?? [:]
      guard let session = args["session"] as? String,
            !session.isEmpty, session.utf8.count <= 128 else {
        result(FlutterError(code: "invalid_tone_session", message: nil, details: nil))
        return
      }
      switch call.method {
      case "play":
        self.stop()
        self.owner = session
        guard let wave = args["wave"] as? FlutterStandardTypedData,
              wave.data.count >= 46, wave.data.count <= 132344 else {
          result(FlutterError(code: "invalid_tone", message: nil, details: nil))
          return
        }
        let volume = (args["volume"] as? NSNumber)?.floatValue ?? 0.3
        guard volume.isFinite else {
          result(FlutterError(code: "invalid_tone", message: nil, details: nil))
          return
        }
        do {
          let next = try AVAudioPlayer(data: wave.data, fileTypeHint: AVFileType.wav.rawValue)
          guard next.duration > 0, next.duration <= 3 else {
            result(FlutterError(code: "invalid_tone", message: nil, details: nil))
            return
          }
          next.delegate = self
          next.volume = min(1, max(0, volume))
          next.numberOfLoops = 0
          self.player = next
          guard next.play() else {
            self.stop()
            result(FlutterError(code: "tone_unavailable", message: nil, details: nil))
            return
          }
          result(nil)
        } catch {
          self.stop()
          result(FlutterError(code: "tone_unavailable", message: nil, details: nil))
        }
      case "stop", "dispose":
        if self.owner == session {
          self.owner = nil
          self.stop()
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func stop() {
    player?.delegate = nil
    player?.stop()
    player = nil
  }

  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    if self.player === player { self.player = nil }
  }

  func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    if self.player === player { stop() }
  }

  func dispose() {
    stop()
    channel.setMethodCallHandler(nil)
  }

  deinit { player?.stop() }
}
