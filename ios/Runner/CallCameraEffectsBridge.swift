import Flutter
import CoreImage
import CoreVideo
import WebRTC
import flutter_webrtc

/// Bộ lọc nằm trước video source/encoder, áp dụng cả preview và video gửi đi.
final class CallCameraEffectsBridge {
  private let channel: FlutterMethodChannel
  private var track: LocalVideoTrack?
  private let processor = CallSkinBrighteningProcessor()

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "soullocket/call_camera_effects", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(false); return }
      switch call.method {
      case "setSkinBrightening":
        guard let args = call.arguments as? [String: Any],
              let id = args["trackId"] as? String,
              let level = args["amount"] as? Double, level.isFinite,
              let local = FlutterWebRTCPlugin.sharedSingleton()?.localTracks?[id] as? LocalVideoTrack,
              self.processor.available else {
          result(FlutterError(code: "effect_unavailable", message: "Camera chưa sẵn sàng.", details: nil))
          return
        }
        if self.track !== local { self.clear(); self.track = local }
        local.removeProcessing(self.processor)
        self.processor.setAmount(max(0, min(1, level)))
        if level > 0 { local.addProcessing(self.processor) }
        result(true)
      case "clear":
        self.clear()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func clear() {
    track?.removeProcessing(processor)
    track = nil
    processor.setAmount(0)
  }

  deinit { channel.setMethodCallHandler(nil); clear() }
}

private final class CallSkinBrighteningProcessor: NSObject, ExternalVideoProcessingDelegate {
  private let lock = NSLock()
  private var amount: Double = 0
  private let context = CIContext(options: [.cacheIntermediates: false])
  private var pool: CVPixelBufferPool?
  private var size = CGSize.zero
  private let kernel = CIColorKernel(source: """
    kernel vec4 brightenSkin(__sample p, float amount) {
      float y = dot(p.rgb, vec3(0.299, 0.587, 0.114));
      float cb = 128.0 - 37.797*p.r - 74.203*p.g + 112.0*p.b;
      float cr = 128.0 + 112.0*p.r - 93.786*p.g - 18.214*p.b;
      float mask = smoothstep(75.0,90.0,cb) * (1.0-smoothstep(125.0,140.0,cb))
        * smoothstep(130.0,142.0,cr) * (1.0-smoothstep(172.0,188.0,cr))
        * smoothstep(20.0,55.0,16.0+219.0*y);
      float lift = max(1.0-y,0.0) * 0.20 * amount * mask;
      return vec4(min(p.rgb+vec3(lift),vec3(1.0)),p.a);
    }
    """)

  var available: Bool { kernel != nil }

  func setAmount(_ value: Double) {
    lock.lock(); amount = value; lock.unlock()
  }

  func onFrame(_ frame: RTCVideoFrame) -> RTCVideoFrame {
    lock.lock(); let level = amount; lock.unlock()
    guard level > 0, let input = frame.buffer as? RTCCVPixelBuffer,
          let kernel = kernel else { return frame }
    let image = CIImage(cvPixelBuffer: input.pixelBuffer)
    let extent = image.extent
    if pool == nil || size != extent.size {
      size = extent.size
      let attributes: [String: Any] = [
        kCVPixelBufferWidthKey as String: Int(extent.width),
        kCVPixelBufferHeightKey as String: Int(extent.height),
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferIOSurfacePropertiesKey as String: [:],
      ]
      CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool)
    }
    guard let pool = pool else { return frame }
    var output: CVPixelBuffer?
    let limits = [kCVPixelBufferPoolAllocationThresholdKey as String: 4] as CFDictionary
    guard CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(nil, pool, limits, &output) == kCVReturnSuccess,
          let output = output,
          let filtered = kernel.apply(extent: extent, arguments: [image, level]) else { return frame }
    context.render(filtered, to: output)
    let buffer = RTCCVPixelBuffer(pixelBuffer: output)
    return RTCVideoFrame(buffer: buffer, rotation: frame.rotation, timeStampNs: frame.timeStampNs)
  }
}
