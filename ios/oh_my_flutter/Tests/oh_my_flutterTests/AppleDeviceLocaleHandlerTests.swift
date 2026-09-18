import Foundation
import XCTest

@testable import oh_my_flutter

final class AppleDeviceLocaleHandlerTests: XCTestCase {
  func testWhenUsingTheOlderOSAPIItShouldReturnTheRegion() {
    XCTAssertEqual(AppleDeviceLocaleHandler.legacyCountry(for: Locale(identifier: "en_BR")), "BR")
  }

  func testWhenLanguageAndRegionDifferItShouldReturnTheRegion() throws {
    let handler = AppleDeviceLocaleHandler(localeProvider: { Locale(identifier: "en_BR") })
    XCTAssertEqual(try handler.getCountry(), "BR")
  }

  func testWhenNoRegionExistsItShouldReturnNil() throws {
    let handler = AppleDeviceLocaleHandler(localeProvider: { Locale(identifier: "en") })
    XCTAssertNil(try handler.getCountry())
  }

  func testWhenRegionChangesItShouldReadTheNewValue() throws {
    var locale = Locale(identifier: "en_US")
    let handler = AppleDeviceLocaleHandler(localeProvider: { locale })
    let first = try handler.getCountry()
    locale = Locale(identifier: "en_BR")
    XCTAssertEqual([first, try handler.getCountry()], ["US", "BR"])
  }

  func testWhenRegionOverrideExistsItShouldUseIt() throws {
    let handler = AppleDeviceLocaleHandler(localeProvider: {
      Locale(identifier: "en-US-u-rg-brzzzz")
    })
    XCTAssertEqual(try handler.getCountry(), "BR")
  }
}
