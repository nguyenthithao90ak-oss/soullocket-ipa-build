import AVFoundation
import Flutter
import UIKit

// Giữ cùng hợp đồng bitrate/kích thước với StorageVideoEncodingProfile của Dart.
struct MemoryVideoEncodingRequest {
  let requestId: String
  let source: URL
  let output: URL
  let width: Int
  let height: Int
  let frameRate: Double
  let videoBitrate: Int
  let audioBitrate: Int
  let includeAudio: Bool

  init(_ values: [String: Any]) throws {
    guard let id = values["requestId"] as? String, !id.isEmpty,
      let path = values["path"] as? String, !path.isEmpty,
      let outputPath = values["outputPath"] as? String, !outputPath.isEmpty,
      let width = values["width"] as? Int, (2...1920).contains(width), width % 2 == 0,
      let height = values["height"] as? Int, (2...1920).contains(height), height % 2 == 0,
      min(width, height) <= 1080,
      let fps = values["frameRate"] as? NSNumber, fps.doubleValue.isFinite,
      fps.doubleValue > 0, fps.doubleValue <= 30,
      let videoBitrate = values["videoBitrate"] as? Int, (400000...5000000).contains(videoBitrate),
      let audioBitrate = values["audioBitrate"] as? Int, (32000...128000).contains(audioBitrate)
    else { throw MemoryVideoFailure("invalid_arguments") }
    source = URL(fileURLWithPath: path).standardizedFileURL
    output = URL(fileURLWithPath: outputPath).standardizedFileURL
    guard source != output, output.pathExtension.lowercased() == "mp4",
      !FileManager.default.fileExists(atPath: output.path),
      FileManager.default.fileExists(atPath: source.path)
    else { throw MemoryVideoFailure("invalid_paths") }
    requestId = id
    self.width = width
    self.height = height
    frameRate = fps.doubleValue
    self.videoBitrate = videoBitrate
    self.audioBitrate = audioBitrate
    includeAudio = values["includeAudio"] as? Bool ?? false
  }
}

struct MemoryVideoFailure: Error {
  let code: String
  init(_ code: String) { self.code = code }
}

final class MemoryVideoEncoderBridge {
  private let channel: FlutterMethodChannel
  private let inspectionQueue = DispatchQueue(label: "soullocket.video.inspect", qos: .userInitiated)
  private let thumbnailQueue = DispatchQueue(label: "soullocket.video.thumbnail", qos: .utility)
  private var inspection: Inspection?
  private var thumbnail: Thumbnail?
  private var compression: MemoryVideoEncodingJob?
  private var closed = false

  private final class Inspection {
    let id: String
    let asset: AVURLAsset
    var result: FlutterResult?
    var cancelled = false
    init(id: String, path: String, result: @escaping FlutterResult) {
      self.id = id
      asset = AVURLAsset(url: URL(fileURLWithPath: path))
      self.result = result
    }
  }

  private final class Thumbnail {
    let id: String
    let asset: AVURLAsset
    let generator: AVAssetImageGenerator
    let maximumBytes: Int
    var result: FlutterResult?
    private let cancellationLock = NSLock()
    private var cancelled = false

    init(id: String, url: URL, maximumBytes: Int, result: @escaping FlutterResult) {
      self.id = id
      self.maximumBytes = maximumBytes
      let asset = AVURLAsset(url: url)
      let generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = CGSize(width: 512, height: 512)
      self.asset = asset
      self.generator = generator
      self.result = result
    }

    var isCancelled: Bool {
      cancellationLock.lock(); defer { cancellationLock.unlock() }
      return cancelled
    }

    func cancel() {
      cancellationLock.lock(); cancelled = true; cancellationLock.unlock()
      generator.cancelAllCGImageGeneration()
      asset.cancelLoading()
    }
  }

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "soullocket/memory_video_encoder", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self, !self.closed else {
        result(FlutterError(code: "encoder_closed", message: nil, details: nil))
        return
      }
      self.handle(call, result: result)
    }
  }

  func dispose() {
    closed = true
    channel.setMethodCallHandler(nil)
    inspection?.cancelled = true
    inspection?.asset.cancelLoading()
    inspection?.result = nil
    thumbnail?.cancel()
    thumbnail?.result = nil
    compression?.cancel()
  }

  deinit { dispose() }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let values = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "inspectVideo":
      guard let path = values["path"] as? String, !path.isEmpty else {
        result(FlutterError(code: "invalid_arguments", message: nil, details: nil)); return
      }
      guard inspection == nil else {
        result(FlutterError(code: "inspect_busy", message: nil, details: nil)); return
      }
      let task = Inspection(id: values["requestId"] as? String ?? UUID().uuidString, path: path, result: result)
      inspection = task
      // Đọc track/container có thể đụng I/O; không đọc metadata trên main thread.
      inspectionQueue.async { [weak self, task] in
        let value: Result<[String: Any], Error> = Result { try Self.inspect(task.asset) }
        DispatchQueue.main.async {
          guard let self = self, self.inspection === task else { return }
          self.inspection = nil
          guard !self.closed, !task.cancelled, let callback = task.result else { return }
          task.result = nil
          switch value {
          case .success(let info): callback(info)
          case .failure: callback(FlutterError(code: "inspect_failed", message: nil, details: nil))
          }
        }
      }
    case "cancelInspection":
      if let task = inspection, task.id == values["requestId"] as? String {
        task.cancelled = true
        task.asset.cancelLoading()
        task.result?(FlutterError(code: "inspect_cancelled", message: nil, details: nil))
        task.result = nil
        // Chỉ nhả busy khi worker đã thoát, tránh tích lũy I/O bị kẹt.
      }
      result(true)
    case "thumbnail":
      guard let rawURL = values["url"] as? String,
        let url = URL(string: rawURL), url.scheme?.lowercased() == "https",
        let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
        let requestId = values["requestId"] as? String, !requestId.isEmpty,
        requestId.utf8.count <= 128
      else {
        result(FlutterError(code: "invalid_thumbnail_arguments", message: nil, details: nil)); return
      }
      guard thumbnail == nil else {
        result(FlutterError(code: "thumbnail_busy", message: nil, details: nil)); return
      }
      let maximumBytes = max(64 * 1024, min(values["maximumSize"] as? Int ?? 1024 * 1024, 1024 * 1024))
      let task = Thumbnail(id: requestId, url: url, maximumBytes: maximumBytes, result: result)
      thumbnail = task
      // Trích frame/JPEG trên queue riêng; album chỉ giữ bitmap, không giữ player.
      thumbnailQueue.async { [weak self, task] in
        let value: Result<Data, Error> = autoreleasepool {
          Result { try Self.makeThumbnail(task) }
        }
        DispatchQueue.main.async {
          guard let self = self, self.thumbnail === task else { return }
          self.thumbnail = nil
          guard !self.closed, !task.isCancelled, let callback = task.result else { return }
          task.result = nil
          switch value {
          case .success(let bytes): callback(FlutterStandardTypedData(bytes: bytes))
          case .failure(let error):
            callback(FlutterError(code: (error as? MemoryVideoFailure)?.code ?? "thumbnail_failed", message: nil, details: nil))
          }
        }
      }
    case "cancelThumbnail":
      if let task = thumbnail, task.id == values["requestId"] as? String {
        task.cancel()
        task.result?(FlutterError(code: "thumbnail_cancelled", message: nil, details: nil))
        task.result = nil
        // Giữ busy tới khi worker thực sự thoát; cancel không mở thêm lượt I/O.
      }
      result(true)
    case "compressVideo":
      guard compression == nil else {
        result(FlutterError(code: "compression_busy", message: nil, details: nil)); return
      }
      do {
        let job = MemoryVideoEncodingJob(try MemoryVideoEncodingRequest(values))
        compression = job
        job.start { [weak self, weak job] value in
          DispatchQueue.main.async {
            guard let self = self, let job = job, self.compression === job else { return }
            self.compression = nil
            guard !self.closed else { return }
            switch value {
            case .success(let path): result(path)
            case .failure(let error):
              result(FlutterError(code: (error as? MemoryVideoFailure)?.code ?? "compression_failed", message: nil, details: nil))
            }
          }
        }
      } catch {
        result(FlutterError(code: (error as? MemoryVideoFailure)?.code ?? "invalid_arguments", message: nil, details: nil))
      }
    case "cancelCompression":
      guard let job = compression, job.request.requestId == values["requestId"] as? String else {
        result(true); return
      }
      // cancelWriting có thể chặn tới khi codec dừng; ACK chỉ sau khi worker dọn xong.
      job.cancel { DispatchQueue.main.async { result(true) } }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func makeThumbnail(_ task: Thumbnail) throws -> Data {
    if task.isCancelled { throw MemoryVideoFailure("thumbnail_cancelled") }
    let image = try task.generator.copyCGImage(at: .zero, actualTime: nil)
    if task.isCancelled { throw MemoryVideoFailure("thumbnail_cancelled") }
    let thumbnail = UIImage(cgImage: image)
    for quality in [0.82, 0.70, 0.58, 0.46, 0.34] {
      if task.isCancelled { throw MemoryVideoFailure("thumbnail_cancelled") }
      guard let data = thumbnail.jpegData(compressionQuality: CGFloat(quality)) else {
        throw MemoryVideoFailure("thumbnail_encode_failed")
      }
      if !data.isEmpty, data.count <= task.maximumBytes { return data }
    }
    throw MemoryVideoFailure("thumbnail_too_large")
  }

  static func inspect(_ asset: AVAsset) throws -> [String: Any] {
    guard let track = asset.tracks(withMediaType: .video).first else {
      throw MemoryVideoFailure("video_track_missing")
    }
    let size = track.naturalSize.applying(track.preferredTransform)
    let duration = CMTimeGetSeconds(asset.duration) * 1000
    guard abs(size.width).isFinite, abs(size.height).isFinite,
      abs(size.width) >= 2, abs(size.height) >= 2, duration.isFinite, duration > 0
    else { throw MemoryVideoFailure("invalid_metadata") }
    return ["width": Int(abs(size.width).rounded()), "height": Int(abs(size.height).rounded()),
      "frameRate": max(0, Double(track.nominalFrameRate)), "durationMs": duration,
      "hasAudio": !asset.tracks(withMediaType: .audio).isEmpty]
  }
}

// Mỗi job có một queue serial: append/finish/cancel không được chạy chồng nhau.
final class MemoryVideoEncodingJob {
  let request: MemoryVideoEncodingRequest
  private let queue = DispatchQueue(label: "soullocket.video.encode", qos: .userInitiated)
  private let cancellationLock = NSLock()
  private var cancelled = false
  private var terminated = false
  private var completion: ((Result<String, Error>) -> Void)?
  private var cancellationWaiters: [() -> Void] = []
  private var reader: AVAssetReader?
  private var writer: AVAssetWriter?
  private var pipes: [Pipe] = []
  private var remaining = 0

  private final class Pipe {
    let output: AVAssetReaderOutput
    let input: AVAssetWriterInput
    var finished = false
    init(_ output: AVAssetReaderOutput, _ input: AVAssetWriterInput) {
      self.output = output; self.input = input
    }
  }

  init(_ request: MemoryVideoEncodingRequest) { self.request = request }

  private var isCancelled: Bool {
    cancellationLock.lock(); defer { cancellationLock.unlock() }
    return cancelled
  }

  func start(completion: @escaping (Result<String, Error>) -> Void) {
    queue.async {
      if self.terminated { completion(.failure(MemoryVideoFailure("compression_cancelled"))); return }
      self.completion = completion
      do {
        if self.isCancelled { throw MemoryVideoFailure("compression_cancelled") }
        try self.configure()
        if self.isCancelled { throw MemoryVideoFailure("compression_cancelled") }
        guard let reader = self.reader, let writer = self.writer, writer.startWriting() else {
          throw MemoryVideoFailure("writer_start_failed")
        }
        guard reader.startReading() else { throw MemoryVideoFailure("reader_start_failed") }
        writer.startSession(atSourceTime: .zero)
        self.remaining = self.pipes.count
        for pipe in self.pipes {
          pipe.input.requestMediaDataWhenReady(on: self.queue) { [weak self, weak pipe] in
            guard let self = self, let pipe = pipe else { return }
            self.pump(pipe)
          }
        }
      } catch { self.finish(.failure(error)) }
    }
  }

  func cancel(onStopped: (() -> Void)? = nil) {
    cancellationLock.lock(); cancelled = true; cancellationLock.unlock()
    queue.async {
      if let callback = onStopped { self.cancellationWaiters.append(callback) }
      if self.terminated { self.notifyCancellationWaiters(); return }
      self.finish(.failure(MemoryVideoFailure("compression_cancelled")))
    }
  }

  private func configure() throws {
    let asset = AVURLAsset(url: request.source)
    guard let video = asset.tracks(withMediaType: .video).first else {
      throw MemoryVideoFailure("video_track_missing")
    }
    let duration = asset.duration
    guard CMTimeGetSeconds(duration).isFinite, CMTimeGetSeconds(duration) > 0 else {
      throw MemoryVideoFailure("invalid_duration")
    }
    let reader = try AVAssetReader(asset: asset)
    let writer = try AVAssetWriter(outputURL: request.output, fileType: .mp4)
    self.reader = reader; self.writer = writer
    writer.shouldOptimizeForNetworkUse = true
    let composition = AVMutableVideoComposition()
    composition.renderSize = CGSize(width: CGFloat(request.width), height: CGFloat(request.height))
    composition.frameDuration = CMTime(seconds: 1 / request.frameRate, preferredTimescale: 60000)
    let bounds = CGRect(origin: .zero, size: video.naturalSize).applying(video.preferredTransform)
    guard bounds.width.isFinite, bounds.height.isFinite, bounds.width > 0, bounds.height > 0 else {
      throw MemoryVideoFailure("invalid_dimensions")
    }
    let scaleX = CGFloat(request.width) / bounds.width
    let scaleY = CGFloat(request.height) / bounds.height
    let transform = video.preferredTransform
      .concatenating(CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY))
      .concatenating(CGAffineTransform(scaleX: scaleX, y: scaleY))
    let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: video)
    layer.setTransform(transform, at: .zero)
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
    instruction.layerInstructions = [layer]
    composition.instructions = [instruction]
    let videoOutput = AVAssetReaderVideoCompositionOutput(videoTracks: [video], videoSettings: [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
    ])
    videoOutput.videoComposition = composition
    videoOutput.alwaysCopiesSampleData = false
    let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: request.width, AVVideoHeightKey: request.height,
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: request.videoBitrate,
        AVVideoExpectedSourceFrameRateKey: request.frameRate,
        AVVideoMaxKeyFrameIntervalKey: max(1, Int(request.frameRate.rounded())),
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
      ],
    ])
    videoInput.expectsMediaDataInRealTime = false
    guard reader.canAdd(videoOutput), writer.canAdd(videoInput) else {
      throw MemoryVideoFailure("video_configuration_failed")
    }
    reader.add(videoOutput); writer.add(videoInput)
    pipes.append(Pipe(videoOutput, videoInput))
    if request.includeAudio, let audio = asset.tracks(withMediaType: .audio).first {
      let audioOutput = AVAssetReaderAudioMixOutput(audioTracks: [audio], audioSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 2, AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
      ])
      audioOutput.alwaysCopiesSampleData = false
      let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100,
        AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: request.audioBitrate,
      ])
      audioInput.expectsMediaDataInRealTime = false
      guard reader.canAdd(audioOutput), writer.canAdd(audioInput) else {
        throw MemoryVideoFailure("audio_configuration_failed")
      }
      reader.add(audioOutput); writer.add(audioInput)
      pipes.append(Pipe(audioOutput, audioInput))
    }
  }

  private func pump(_ pipe: Pipe) {
    guard !terminated, !pipe.finished else { return }
    while pipe.input.isReadyForMoreMediaData {
      if isCancelled { finish(.failure(MemoryVideoFailure("compression_cancelled"))); return }
      // Không giữ cả video trong RAM; mỗi vòng chỉ sở hữu một sample buffer.
      let appended: Bool? = autoreleasepool {
        guard let sample = pipe.output.copyNextSampleBuffer() else { return nil }
        return pipe.input.append(sample)
      }
      if appended == false { finish(.failure(MemoryVideoFailure("append_failed"))); return }
      if appended == nil {
        if reader?.status == .failed { finish(.failure(MemoryVideoFailure("read_failed"))); return }
        pipe.finished = true
        pipe.input.markAsFinished()
        remaining -= 1
        if remaining == 0 {
          writer?.finishWriting { [weak self] in
            guard let self = self else { return }
            self.queue.async {
              if self.isCancelled { self.finish(.failure(MemoryVideoFailure("compression_cancelled"))) }
              else if self.writer?.status == .completed {
                self.finish(.success(self.request.output.path))
              } else { self.finish(.failure(MemoryVideoFailure("finish_failed"))) }
            }
          }
        }
        return
      }
    }
  }

  private func finish(_ value: Result<String, Error>) {
    guard !terminated else { return }
    terminated = true
    if case .failure = value {
      reader?.cancelReading()
      if let writer = writer, writer.status == .writing || writer.status == .unknown {
        writer.cancelWriting()
      }
      try? FileManager.default.removeItem(at: request.output)
    }
    pipes.removeAll()
    reader = nil; writer = nil
    let callback = completion; completion = nil
    callback?(value)
    notifyCancellationWaiters()
  }

  private func notifyCancellationWaiters() {
    let callbacks = cancellationWaiters; cancellationWaiters.removeAll()
    callbacks.forEach { $0() }
  }
}
