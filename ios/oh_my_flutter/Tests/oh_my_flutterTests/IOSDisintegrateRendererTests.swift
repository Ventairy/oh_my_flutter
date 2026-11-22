import CoreVideo
import Metal
import XCTest

@testable import oh_my_flutter

final class IOSDisintegrateRendererTests: XCTestCase {
  func testWhenTheImageIsIntactItShouldCoverEveryPixelAcrossParticleBoundaries() throws {
    let context = try makeContext()
    var gaps: [Int] = []
    for width in 220...280 {
      let image = try render(context: context, width: width, progress: 0, translation: 0, alpha: 255)
      if alphaValues(in: image, columns: 16..<(16 + width), rows: 16..<64).contains(where: { $0 != 255 }) {
        gaps.append(width)
      }
    }

    XCTAssertEqual(gaps, [])
  }

  func testWhenPartiallyDisintegratedItShouldPreserveTranslucentPixelsInIntactCells() throws {
    let context = try makeContext()
    let image = try render(context: context, width: 255, progress: 0.035, translation: 0.25, alpha: 128)
    let intactPixels = alphaValues(in: image, columns: 120..<270, rows: 17..<63)

    XCTAssertEqual(Set(intactPixels), [128])
  }

  func testWhenNativeGaussianStartsAtZeroItShouldKeepTheDirectOutput() throws {
    let context = try makeContext()
    let standard = try render(context: context, width: 30, progress: 0.2, translation: 0.25, alpha: 128)
    let gaussian = try render(context: context, width: 30, progress: 0.2, translation: 0.25, alpha: 128, gaussian: (0, 0))

    XCTAssertEqual(alphaValues(in: gaussian, columns: 0..<62, rows: 0..<80),
      alphaValues(in: standard, columns: 0..<62, rows: 0..<80))
  }

  func testWhenReplayingWithNewSigmaItShouldLeaveThePreviouslyPublishedBufferIntact() throws {
    let context = try makeContext()
    let configuration = try IOSDisintegrateTestFixture.configuration(overrides: [
      "nativeGaussian": true, "viewportWidth": 32, "viewportHeight": 28, "originX": 10, "originY": 10,
      "frame": IOSDisintegrateTestFixture.frame(gaussian: (2, 4)),
    ])
    let renderer = try IOSDisintegrateRenderer(configuration: configuration, context: context)
    let pixels = IOSDisintegrateTestFixture.pixels(rgba: [128, 0, 0, 128])
    try renderer.uploadImage(pixels, frame: configuration.initialFrame)
    let blurred = try render(renderer, progress: 0)
    renderer.releaseImage()

    let sharpFrame = try IOSDisintegrateConfiguration.frame(
      from: IOSDisintegrateTestFixture.frame(gaussian: (0, 0)), nativeGaussian: true)
    try renderer.uploadImage(pixels, frame: sharpFrame)
    let sharp = try render(renderer, progress: 0)

    XCTAssertEqual([blurred, sharp].map { alphaValues(in: $0, columns: 9..<10, rows: 13..<14)[0] > 0 }, [true, false])
  }

  private func makeContext() throws -> IOSDisintegrateMetalContext {
    guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal is unavailable on this test host.") }
    return try IOSDisintegrateMetalContext()
  }

  private func render(context: IOSDisintegrateMetalContext, width: Int, progress: Float,
    translation: Double, alpha: UInt8, gaussian: (texture: Double, display: Double)? = nil) throws -> CVPixelBuffer {
    var frame: [Double] = [Double(progress), 1, 0, translation, translation, 1, 0, 0, 0, 1, 1, 0, 0, 0]
    if let gaussian { frame += [gaussian.texture, gaussian.display] }
    let configuration = try IOSDisintegrateTestFixture.configuration(overrides: [
      "width": width, "height": 48, "viewportWidth": width + 32, "viewportHeight": 80,
      "originX": 16, "originY": 16, "minimumCellSize": 2.2, "maximumParticleCount": 18_000,
      "nativeGaussian": gaussian != nil,
      "frame": IOSDisintegrateTestFixture.typedData(frame),
    ])
    let renderer = try IOSDisintegrateRenderer(configuration: configuration, context: context)
    try renderer.uploadImage(Data(repeating: alpha, count: width * 48 * 4), frame: configuration.initialFrame)
    return try render(renderer, progress: progress)
  }

  private func render(_ renderer: IOSDisintegrateRenderer, progress: Float) throws -> CVPixelBuffer {
    let rendered = expectation(description: "Metal output is ready")
    var output: Result<CVPixelBuffer, Error>?
    renderer.render(progress: progress) { result in
      output = result
      rendered.fulfill()
    }
    wait(for: [rendered], timeout: 5)
    return try XCTUnwrap(output).get()
  }

  private func alphaValues(in buffer: CVPixelBuffer, columns: Range<Int>, rows: Range<Int>) -> [UInt8] {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    let stride = CVPixelBufferGetBytesPerRow(buffer)
    let bytes = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
    return rows.flatMap { row in columns.map { bytes[row * stride + $0 * 4 + 3] } }
  }
}
