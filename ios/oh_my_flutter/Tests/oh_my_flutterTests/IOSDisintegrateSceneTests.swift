import CoreVideo
import Flutter
import Metal
import XCTest

@testable import oh_my_flutter

@MainActor final class IOSDisintegrateSceneTests: XCTestCase {
  func testWhenTheFirstImageHasNotBeenAcquiredItShouldWaitBeforeAcknowledgingReadiness() throws {
    let configuration = try IOSDisintegrateTestFixture.configuration()
    let registry = IOSDisintegrateTextureRegistrySpy()
    let scene = try scene(configuration: configuration, registry: registry)
    defer { scene.close() }
    prepare(scene, configuration: configuration)
    let ready = expectation(description: "The ready image is acquired")
    var acknowledged = false
    scene.awaitFirstFrame { value in
      XCTAssertNil(value)
      acknowledged = true
      ready.fulfill()
    }
    XCTAssertFalse(acknowledged)
    _ = registry.textures[scene.textureId]?.copyPixelBuffer()?.takeRetainedValue()

    wait(for: [ready], timeout: 5)
  }

  func testWhenPreparingTheFirstImageItShouldPreserveTheSourceColorAndOrientation() throws {
    let configuration = try IOSDisintegrateTestFixture.configuration()
    let registry = IOSDisintegrateTextureRegistrySpy()
    let scene = try scene(configuration: configuration, registry: registry)
    defer { scene.close() }
    let quadrants: [[UInt8]] = [[255, 0, 0, 255], [0, 255, 0, 255], [0, 0, 255, 255], [255, 255, 0, 255]]
    let pixels = Data((0..<96).flatMap { pixel in quadrants[(pixel / 12 < 4 ? 0 : 2) + (pixel % 12 < 6 ? 0 : 1)] })
    prepare(scene, configuration: configuration, pixels: pixels)
    let image = try XCTUnwrap(registry.textures[scene.textureId]?.copyPixelBuffer()?.takeRetainedValue())
    CVPixelBufferLockBaseAddress(image, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(image, .readOnly) }
    let bytes = try XCTUnwrap(CVPixelBufferGetBaseAddress(image)).assumingMemoryBound(to: UInt8.self)
    let corners = [(3, 2), (9, 2), (3, 6), (9, 6)].map { x, y in
      Array(UnsafeBufferPointer(start: bytes + y * CVPixelBufferGetBytesPerRow(image) + x * 4, count: 4))
    }

    XCTAssertEqual(corners, [[0, 0, 255, 255], [0, 255, 0, 255], [255, 0, 0, 255], [0, 255, 255, 255]])
  }

  func testWhenReleasingAnImageBeforePreparationCompletesItShouldNotPublishTheLateImage() throws {
    let configuration = try IOSDisintegrateTestFixture.configuration()
    let registry = IOSDisintegrateTextureRegistrySpy()
    let renderQueue = DispatchQueue(label: "omf.disintegrate.tests.paused")
    let scene = try scene(configuration: configuration, registry: registry, renderQueue: renderQueue)
    defer { scene.close() }
    let prepared = expectation(description: "Stale preparation completes")
    let released = expectation(description: "The image is released")
    renderQueue.suspend()
    scene.prepareImage(IOSDisintegrateTestFixture.pixels(), handle: 4, frame: configuration.initialFrame) { value in
      XCTAssertNotNil(value as? FlutterError)
      prepared.fulfill()
    }
    scene.releaseImage { _ in released.fulfill() }
    renderQueue.resume()
    wait(for: [prepared, released], timeout: 10)

    XCTAssertTrue(registry.notifications.isEmpty)
  }

  func testWhenClosingASceneItShouldUnregisterOnlyItsOwnTexture() throws {
    let configuration = try IOSDisintegrateTestFixture.configuration()
    let registry = IOSDisintegrateTextureRegistrySpy()
    let first = try scene(configuration: configuration, registry: registry)
    let second = try scene(configuration: configuration, registry: registry)
    defer { second.close() }
    first.close()

    XCTAssertEqual(Array(registry.textures.keys), [second.textureId])
  }

  func testWhenParticlesExceedMetalPointLimitsItShouldRejectTheOutput() throws {
    let configuration = try IOSDisintegrateTestFixture.configuration(overrides: [
      "width": 600, "height": 600, "viewportWidth": 600, "viewportHeight": 600,
      "minimumCellSize": 600,
    ])
    let registry = IOSDisintegrateTextureRegistrySpy()
    let scene = try scene(configuration: configuration, registry: registry)
    defer { scene.close() }
    let rejected = expectation(description: "Unsupported point geometry is rejected")
    scene.prepareImage(IOSDisintegrateTestFixture.pixels(width: 600, height: 600), handle: 1,
      frame: configuration.initialFrame) { value in
      XCTAssertNotNil(value as? FlutterError)
      rejected.fulfill()
    }

    wait(for: [rejected], timeout: 10)
  }

  private func scene(configuration: IOSDisintegrateConfiguration, registry: IOSDisintegrateTextureRegistrySpy,
    renderQueue: DispatchQueue = DispatchQueue(label: "omf.disintegrate.tests")) throws -> IOSDisintegrateScene {
    guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal is unavailable on this test host.") }
    return IOSDisintegrateScene(configuration: configuration, registry: registry, renderQueue: renderQueue,
      makeContext: { try IOSDisintegrateMetalContext() })
  }

  private func prepare(_ scene: IOSDisintegrateScene, configuration: IOSDisintegrateConfiguration,
    pixels: Data = IOSDisintegrateTestFixture.pixels()) {
    let prepared = expectation(description: "The first Metal image is rendered")
    scene.prepareImage(pixels, handle: 1, frame: configuration.initialFrame) { value in
      XCTAssertNotNil(value as? [String: Any], "Preparation failed: \(String(describing: value))")
      prepared.fulfill()
    }
    wait(for: [prepared], timeout: 10)
  }
}
