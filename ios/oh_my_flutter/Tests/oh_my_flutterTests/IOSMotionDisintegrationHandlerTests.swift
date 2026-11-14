import Flutter
import Metal
import XCTest

@testable import oh_my_flutter

@MainActor final class IOSMotionDisintegrationHandlerTests: XCTestCase {
  func testWhenTheRendererIsColdItShouldWarmWithoutAllocatingTextures() async throws {
    guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal is unavailable on this test host.") }
    let registry = IOSDisintegrateTextureRegistrySpy()
    let handler = IOSMotionDisintegrationHandler(binaryMessenger: IOSNativeSelectableTextMenuBinaryMessengerSpy(), registry: registry)
    defer { handler.dispose() }

    let firstResponse = isRendererReady(handler)
    XCTAssertEqual(firstResponse, false)
    XCTAssertTrue(registry.textures.isEmpty)
    guard firstResponse == false else { return }

    for _ in 0..<1000 {
      if isRendererReady(handler) == true {
        XCTAssertTrue(registry.textures.isEmpty)
        return
      }
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("The renderer should become ready after warming its shared Metal pipeline.")
  }

  func testWhenTheEngineUnregistersATextureItShouldCreateANewSceneOnReplay() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("Metal is unavailable on this test host.") }
    let registry = IOSDisintegrateTextureRegistrySpy()
    let handler = IOSMotionDisintegrationHandler(binaryMessenger: IOSNativeSelectableTextMenuBinaryMessengerSpy(), registry: registry)
    defer { handler.dispose() }
    let first = prepare(handler)
    let originalTexture = try XCTUnwrap((first?["textureId"] as? NSNumber)?.int64Value)
    let texture = try XCTUnwrap(registry.textures[originalTexture])
    texture.onTextureUnregistered?(texture)
    let closed = expectation(description: "The raster-thread callback closes its scene")
    DispatchQueue.main.async { closed.fulfill() }
    wait(for: [closed], timeout: 2)
    let replacement = prepare(handler)

    XCTAssertNotEqual((replacement?["textureId"] as? NSNumber)?.int64Value, originalTexture)
    XCTAssertNotNil(replacement)
  }

  private func isRendererReady(_ handler: IOSMotionDisintegrationHandler) -> Bool? {
    var response: Bool?
    handler.handle(FlutterMethodCall(methodName: "prepareRenderer", arguments: [:])) { value in
      response = value as? Bool
    }
    return response
  }

  private func prepare(_ handler: IOSMotionDisintegrationHandler) -> [String: Any]? {
    let prepared = expectation(description: "The prepared source has a registered texture")
    var response: [String: Any]?
    let arguments = IOSDisintegrateTestFixture.arguments(overrides: [
      "instanceId": 1,
      "image": FlutterStandardTypedData(bytes: IOSDisintegrateTestFixture.pixels()),
    ])
    handler.handle(FlutterMethodCall(methodName: "prepare", arguments: arguments)) { value in
      response = value as? [String: Any]
      prepared.fulfill()
    }
    wait(for: [prepared], timeout: 10)
    return response
  }
}
