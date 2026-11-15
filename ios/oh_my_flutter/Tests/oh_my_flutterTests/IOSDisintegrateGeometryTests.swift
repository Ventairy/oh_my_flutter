import Flutter
import Foundation
import XCTest

@testable import oh_my_flutter

final class IOSDisintegrateGeometryTests: XCTestCase {
  func testWhenGeneratingParticlesItShouldMatchTheSharedCReferenceBitForBit() throws {
    let geometry = IOSDisintegrateGeometry(configuration: try IOSDisintegrateTestFixture.configuration())
    let expected: [UInt32] = [
      0x00000000, 0x00000000, 0x40800000, 0x40800000, 0x38ddc929, 0x3f58d99e,
      0xbeb16aea, 0xbf71c6c5, 0x40b0047d, 0x3d9c352f, 0x40800000, 0x00000000,
      0x41000000, 0x40800000, 0x3db40e30, 0x3f41477c, 0xbf6ffaf2, 0xbeceaa57,
      0x408bed0f, 0x3e058a25, 0x41000000, 0x00000000, 0x41400000, 0x40800000,
      0x3e0a68db, 0x3f219917, 0xbf2d7a90, 0xbed08c83, 0x3f4b16f9, 0x3d1877d1,
      0x00000000, 0x40800000, 0x40800000, 0x41000000, 0x3d051dcd, 0x3f505386,
      0xbf76927c, 0xbf304adc, 0x4060a200, 0x3dd60ad0, 0x40800000, 0x40800000,
      0x41000000, 0x41000000, 0x3d9326a8, 0x3f14faa3, 0xbf771f8d, 0xbf246b23,
      0x406312ec, 0x3d8ce7f3, 0x41000000, 0x40800000, 0x41400000, 0x41000000,
      0x3de6df5b, 0x3f2a2458, 0xbf8f6f1f, 0xbefe2e51, 0x407fcbe1, 0x3de94a6a,
    ]

    XCTAssertEqual(geometry.attributes.map(\.bitPattern), expected)
  }

  func testWhenTheSourceRequiresManyParticlesItShouldKeepTheAdaptiveBudget() throws {
    let configuration = try IOSDisintegrateTestFixture.configuration(overrides: [
      "width": 358, "height": 687, "maximumParticleCount": 18_000, "minimumCellSize": 2.2,
    ])
    let geometry = IOSDisintegrateGeometry(configuration: configuration)

    XCTAssertEqual([geometry.columns, geometry.rows, geometry.particleCount], [97, 185, 17_945])
  }

  func testWhenPreparingUniformsItShouldKeepTheFrameAndMotionPacketOrder() throws {
    let configuration = try IOSDisintegrateTestFixture.configuration()
    let expected: [Float] = [
      12, 8, 12, 8, 0, 0, 1, 1,
      0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0,
      5, 0.4, 0.7, 3, 0.1, 2,
    ]

    XCTAssertEqual(configuration.makeUniforms(frame: configuration.initialFrame), expected)
  }

  func testWhenOnlyTheInitialFrameChangesItShouldReuseThePreparedGeometry() throws {
    let original = try IOSDisintegrateTestFixture.configuration()
    var frame: [Double] = [0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0]
    frame[0] = 0.5
    let replacement = try IOSDisintegrateTestFixture.configuration(overrides: ["frame": IOSDisintegrateTestFixture.typedData(frame)])

    XCTAssertTrue(original.matches(replacement))
  }

  func testWhenTheParticleSizeChangesItShouldReplaceThePreparedGeometry() throws {
    let original = try IOSDisintegrateTestFixture.configuration()
    let replacement = try IOSDisintegrateTestFixture.configuration(overrides: ["minimumCellSize": 2])

    XCTAssertFalse(original.matches(replacement))
  }

  func testWhenTheFrameIsNotFiniteItShouldRejectThePacket() {
    var frame: [Double] = [0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 0]
    frame[4] = .infinity

    XCTAssertThrowsError(try IOSDisintegrateConfiguration.frame(from: IOSDisintegrateTestFixture.typedData(frame)))
  }

  func testWhenTheParticleSizeIsNotPositiveItShouldRejectTheConfiguration() {
    XCTAssertThrowsError(try IOSDisintegrateTestFixture.configuration(overrides: ["minimumCellSize": 0]))
  }

  func testWhenTheMotionPacketIsMissingItShouldRejectTheConfiguration() {
    XCTAssertThrowsError(try IOSDisintegrateTestFixture.configuration(overrides: ["motionParameters": IOSDisintegrateTestFixture.typedData([])]))
  }

}
