import Foundation
import Metal
import XCTest

@testable import oh_my_flutter

final class IOSDisintegrateGaussianTests: XCTestCase {
  func testWhenTheFilterSamplesBeyondTheTextureItShouldUseTransparentPixels() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal is unavailable on this test host.") }
    let context = try IOSDisintegrateMetalContext()
    let size = 12
    let filter = try IOSDisintegrateGaussian(context: context, width: size, height: size)
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm, width: size, height: size, mipmapped: false)
    descriptor.storageMode = .shared
    descriptor.usage = [.renderTarget, .shaderRead]
    let target = try XCTUnwrap(context.device.makeTexture(descriptor: descriptor))
    let opaque = Data(repeating: 255, count: size * size * 4)
    opaque.withUnsafeBytes { bytes in
      target.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0,
        withBytes: bytes.baseAddress!, bytesPerRow: size * 4)
    }

    let commands = try XCTUnwrap(context.commandQueue.makeCommandBuffer())
    try filter.encode(target: target, sigma: 1.4, displaySigma: 2.8, commands: commands)
    commands.commit()
    commands.waitUntilCompleted()
    if let error = commands.error { throw error }
    var edge = SIMD4<UInt8>.zero
    target.getBytes(&edge, bytesPerRow: 4, from: MTLRegionMake2D(0, size / 2, 1, 1), mipmapLevel: 0)
    let weight = exp(-0.5 / (1.4 * 1.4)) + exp(-2 / (1.4 * 1.4))
    let expected = Int((255 * (1 + weight) / (1 + 2 * weight)).rounded())

    XCTAssertLessThanOrEqual((0..<4).map { abs(Int(edge[$0]) - expected) }.max()!, 1)
  }
}
