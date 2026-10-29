import AVFoundation
import Flutter
@testable import Runner
import UIKit
import XCTest

class RunnerTests: XCTestCase {

  @MainActor
  func testAppDelegateSupportsImplicitEngine() throws {
    let appDelegate = try XCTUnwrap(UIApplication.shared.delegate)
    XCTAssertTrue(appDelegate is FlutterImplicitEngineDelegate)
  }

  @MainActor
  func testSceneConnectsFlutterEngineAndPlugins() throws {
    // Chạy trên simulator/iPhone: xác nhận storyboard thực sự nối scene và engine.
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.first { $0.delegate is FlutterSceneDelegate }
        as? UIWindowScene
    )
    let window = try XCTUnwrap(
      scene.windows.first { $0.rootViewController is FlutterViewController }
    )
    let controller = try XCTUnwrap(window.rootViewController as? FlutterViewController)
    let engine = try XCTUnwrap(controller.engine)
    for plugin in ["FLTFirebaseCorePlugin", "FirebaseAppCheckPlugin", "WorkmanagerPlugin"] {
      XCTAssertTrue(engine.hasPlugin(plugin), "Plugin chưa đăng ký trên engine của scene: \(plugin)")
    }
  }


  func testMemoryEncoderAppliesRotationFrameRateAndH264Profile() throws {
    let source = try makeVideoFixture()
    let output = source.deletingLastPathComponent().appendingPathComponent("encoded.mp4")
    defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
    let sourceInfo = try MemoryVideoEncoderBridge.inspect(AVURLAsset(url: source))
    XCTAssertEqual(sourceInfo["width"] as? Int, 180)
    XCTAssertEqual(sourceInfo["height"] as? Int, 320)
    let request = try memoryRequest(source: source, output: output)
    let job = MemoryVideoEncodingJob(request)
    let finished = expectation(description: "Mã hóa MOV sang MP4")
    var outcome: Result<String, Error>?
    job.start { value in outcome = value; finished.fulfill() }
    wait(for: [finished], timeout: 30)
    XCTAssertEqual(try XCTUnwrap(outcome).get(), output.path)
    let asset = AVURLAsset(url: output)
    let info = try MemoryVideoEncoderBridge.inspect(asset)
    XCTAssertEqual(info["width"] as? Int, 90)
    XCTAssertEqual(info["height"] as? Int, 160)
    XCTAssertLessThanOrEqual(try XCTUnwrap(info["frameRate"] as? Double), 30.1)
    XCTAssertGreaterThan(try XCTUnwrap(info["durationMs"] as? Double), 100)
    let track = try XCTUnwrap(asset.tracks(withMediaType: .video).first)
    let format = try XCTUnwrap(track.formatDescriptions.first as? CMFormatDescription)
    XCTAssertEqual(CMFormatDescriptionGetMediaSubType(format), kCMVideoCodecType_H264)
    XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
  }

  func testMemoryEncoderCancelBeforeStartCompletesAndRemovesPartialOutput() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = directory.appendingPathComponent("source.mov")
    try Data([0, 1, 2]).write(to: source)
    let output = directory.appendingPathComponent("cancelled.mp4")
    let job = MemoryVideoEncodingJob(try memoryRequest(source: source, output: output))
    let cancelled = expectation(description: "Hủy trước khi worker bắt đầu")
    job.cancel()
    job.start { value in
      if case .failure(let error) = value {
        XCTAssertEqual((error as? MemoryVideoFailure)?.code, "compression_cancelled")
      } else { XCTFail("Tác vụ đã hủy không được trả đường dẫn thành công") }
      cancelled.fulfill()
    }
    wait(for: [cancelled], timeout: 5)
    XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    XCTAssertEqual(try Data(contentsOf: source), Data([0, 1, 2]))
  }

  func testMemoryEncoderRejectsOverwritingSourceAndMalformedVideo() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let source = directory.appendingPathComponent("bad.mp4")
    try Data([0, 1, 2]).write(to: source)
    XCTAssertThrowsError(try memoryRequest(source: source, output: source))
    let output = directory.appendingPathComponent("failed.mp4")
    let job = MemoryVideoEncodingJob(try memoryRequest(source: source, output: output))
    let failed = expectation(description: "Video hỏng trả lỗi và dọn file")
    job.start { value in
      if case .success = value { XCTFail("Không được nhận video hỏng") }
      failed.fulfill()
    }
    wait(for: [failed], timeout: 10)
    XCTAssertFalse(FileManager.default.fileExists(atPath: output.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
  }

  private func memoryRequest(source: URL, output: URL) throws -> MemoryVideoEncodingRequest {
    try MemoryVideoEncodingRequest([
      "requestId": UUID().uuidString, "path": source.path, "outputPath": output.path,
      "width": 90, "height": 160, "frameRate": 30.0,
      "videoBitrate": 400000, "audioBitrate": 96000, "includeAudio": false,
    ])
  }

  private func makeVideoFixture() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let source = directory.appendingPathComponent("live-photo.mov")
    let writer = try AVAssetWriter(outputURL: source, fileType: .mov)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
      AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 180,
    ])
    input.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 180, ty: 0)
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
      sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
        kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 180])
    writer.add(input)
    XCTAssertTrue(writer.startWriting())
    writer.startSession(atSourceTime: .zero)
    let written = expectation(description: "Tạo fixture MOV 60fps có rotation")
    let queue = DispatchQueue(label: "soullocket.test.video-fixture")
    var frame = 0
    input.requestMediaDataWhenReady(on: queue) {
      while input.isReadyForMoreMediaData && frame < 24 {
        var buffer: CVPixelBuffer?
        guard let pool = adaptor.pixelBufferPool,
          CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess,
          let buffer = buffer else { XCTFail("Không tạo được pixel buffer"); written.fulfill(); return }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
          memset(base, 120, CVPixelBufferGetBytesPerRow(buffer) * CVPixelBufferGetHeight(buffer))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        XCTAssertTrue(adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 60)))
        frame += 1
      }
      if frame == 24 {
        frame += 1
        input.markAsFinished()
        writer.finishWriting { written.fulfill() }
      }
    }
    wait(for: [written], timeout: 15)
    XCTAssertEqual(writer.status, .completed)
    return source
  }

}
