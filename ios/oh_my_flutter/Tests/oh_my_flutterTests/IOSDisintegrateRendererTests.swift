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

  private func makeContext() throws -> IOSDisintegrateMetalContext {
    guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal is unavailable on this test host.") }
    return try IOSDisintegrateMetalContext()
  }

  private func render(context: IOSDisintegrateMetalContext, width: Int, progress: Float,
    translation: Double, alpha: UInt8) throws -> CVPixelBuffer {
    let configuration = try IOSDisintegrateTestFixture.configuration(overrides: [
      "width": width, "height": 48, "viewportWidth": width + 32, "viewportHeight": 80,
      "originX": 16, "originY": 16, "minimumCellSize": 2.2, "maximumParticleCount": 18_000,
      "frame": IOSDisintegrateTestFixture.typedData([Double(progress), 1, 0, translation, translation,
        1, 0, 0, 0, 1, 1, 0, 0, 0]),
    ])
    let renderer = try IOSDisintegrateRenderer(configuration: configuration, context: context)
    try renderer.uploadImage(Data(repeating: alpha, count: width * 48 * 4), frame: configuration.initialFrame)
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
