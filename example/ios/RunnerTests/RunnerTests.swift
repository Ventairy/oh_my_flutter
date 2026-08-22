import XCTest

final class RunnerTests: XCTestCase {
  func testWhenDeviceLocationIsExposedItShouldDeclarePurposeString() {
    let purpose = Bundle.main.object(
      forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription"
    ) as? String

    XCTAssertFalse(purpose?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
  }
}
