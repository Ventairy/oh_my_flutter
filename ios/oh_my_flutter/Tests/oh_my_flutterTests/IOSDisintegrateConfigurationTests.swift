import XCTest

@testable import oh_my_flutter

final class IOSDisintegrateConfigurationTests: XCTestCase {
  func testWhenGaussianIsNotNegotiatedItShouldRejectExtraFrameFields() {
    let frame = IOSDisintegrateTestFixture.frame(gaussian: (1, 2))

    XCTAssertThrowsError(try IOSDisintegrateConfiguration.frame(from: frame))
  }

  func testWhenTextureSigmaExceedsTheNativeLimitItShouldRejectTheFrame() {
    let frame = IOSDisintegrateTestFixture.frame(gaussian: (8.01, 16))

    XCTAssertThrowsError(try IOSDisintegrateConfiguration.frame(from: frame, nativeGaussian: true))
  }

  func testWhenGaussianSigmasDisagreeAboutZeroItShouldRejectTheFrame() {
    let frame = IOSDisintegrateTestFixture.frame(gaussian: (1, 0))

    XCTAssertThrowsError(try IOSDisintegrateConfiguration.frame(from: frame, nativeGaussian: true))
  }

  func testWhenOnlyGaussianNegotiationDiffersItShouldNotReuseTheRenderer() throws {
    let standard = try IOSDisintegrateTestFixture.configuration()
    let gaussian = try IOSDisintegrateTestFixture.configuration(overrides: [
      "nativeGaussian": true, "frame": IOSDisintegrateTestFixture.frame(gaussian: (0, 0)),
    ])

    XCTAssertFalse(standard.matches(gaussian))
  }
}
