import CoreVideo
import XCTest

@testable import oh_my_flutter

final class IOSDisintegrateTextureTests: XCTestCase {
  func testWhenNoImageWasPublishedItShouldReturnNoBuffer() {
    XCTAssertNil(IOSDisintegrateTexture().copyPixelBuffer())
  }

  func testWhenAnImageWasPublishedItShouldReturnTheSameRetainedBuffer() throws {
    let texture = IOSDisintegrateTexture()
    let image = try pixelBuffer()
    texture.publish(image, handle: 1)

    XCTAssertTrue(texture.copyPixelBuffer()?.takeRetainedValue() === image)
  }

  func testWhenAnImageIsClearedItShouldStopReturningItsBuffer() throws {
    let texture = IOSDisintegrateTexture()
    texture.publish(try pixelBuffer(), handle: 1)
    texture.clear()

    XCTAssertNil(texture.copyPixelBuffer())
  }

  func testWhenTheSameImageIsReadTwiceItShouldAcknowledgeOnlyOnce() throws {
    let texture = IOSDisintegrateTexture()
    let acquired = expectation(description: "The image is acquired")
    acquired.assertForOverFulfill = true
    texture.onImageAcquired = { handle in
      XCTAssertEqual(handle, 5)
      acquired.fulfill()
    }
    texture.publish(try pixelBuffer(), handle: 5)
    _ = texture.copyPixelBuffer()?.takeRetainedValue()
    _ = texture.copyPixelBuffer()?.takeRetainedValue()

    wait(for: [acquired], timeout: 2)
  }

  private func pixelBuffer() throws -> CVPixelBuffer {
    var image: CVPixelBuffer?
    let status = CVPixelBufferCreate(nil, 2, 2, kCVPixelFormatType_32BGRA, nil, &image)
    XCTAssertEqual(status, kCVReturnSuccess)
    return try XCTUnwrap(image)
  }
}
