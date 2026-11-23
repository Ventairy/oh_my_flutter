import Foundation
import MarketplaceKit
import XCTest

@testable import oh_my_flutter

final class IOSTestFlightHandlerTests: XCTestCase {
  @available(iOS 17.4, *)
  func testWhenInstalledThroughTestFlightItShouldReturnTrue() async {
    let result = await IOSTestFlightHandler.resolve { .testFlight }
    XCTAssertEqual(result, true)
  }

  @available(iOS 17.4, *)
  func testWhenInstalledThroughAnotherSourceItShouldReturnFalse() async {
    let result = await IOSTestFlightHandler.resolve { .appStore }
    XCTAssertEqual(result, false)
  }

  @available(iOS 17.4, *)
  func testWhenDistributorLookupFailsItShouldReturnNil() async {
    let result = await IOSTestFlightHandler.resolve { throw CocoaError(.fileReadUnknown) }
    XCTAssertNil(result)
  }

  func testWhenRunningLocallyItShouldReturnFalse() async {
    let result = await IOSTestFlightHandler().checkTestFlight()
    XCTAssertEqual(result, false)
  }
}
