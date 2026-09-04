import Flutter
import Foundation
import XCTest

@testable import oh_my_flutter

final class IOSNativeSelectableTextMenuHandlerTests: XCTestCase {
  func testWhenThePresenterIsUnavailableItShouldRejectPresentation() {
    let handler = IOSNativeSelectableTextMenuHandler(presenter: nil)

    let didShow = handler.show(request: request(sessionIdentifier: 11))

    XCTAssertFalse(didShow)
  }

  func testWhenPresentationIsAvailableItShouldForwardTheSession() {
    let presenter = IOSNativeSelectableTextMenuPresenterFake()
    let handler = IOSNativeSelectableTextMenuHandler(presenter: presenter)

    _ = handler.show(request: request(sessionIdentifier: 12))

    XCTAssertEqual(presenter.shownRequest?.sessionIdentifier, 12)
  }

  func testWhenAnUpdateIsRequestedItShouldReturnThePresenterResult() {
    let presenter = IOSNativeSelectableTextMenuPresenterFake()
    presenter.updateResult = false
    let handler = IOSNativeSelectableTextMenuHandler(presenter: presenter)

    let didUpdate = handler.update(request: request(sessionIdentifier: 13))

    XCTAssertFalse(didUpdate)
  }

  func testWhenAGeometryUpdateIsRequestedItShouldForwardTheExactPayload() {
    let presenter = IOSNativeSelectableTextMenuPresenterFake()
    presenter.updateGeometryResult = false
    let handler = IOSNativeSelectableTextMenuHandler(presenter: presenter)
    let geometry = geometry(10, 20, 30, 40, 50, 60)

    let didUpdate = handler.updateGeometry(sessionIdentifier: 15, geometry: geometry)

    XCTAssertTrue(
      !didUpdate
        && presenter.updatedGeometrySessionIdentifier == 15
        && presenter.updatedGeometry === geometry
    )
  }

  func testWhenASessionIsHiddenItShouldForwardItsIdentifier() {
    let presenter = IOSNativeSelectableTextMenuPresenterFake()
    let handler = IOSNativeSelectableTextMenuHandler(presenter: presenter)

    handler.hide(sessionIdentifier: 14)

    XCTAssertEqual(presenter.hiddenSessionIdentifier, 14)
  }

  func testWhenTheHandlerIsDisposedItShouldDisposeItsPresenter() {
    let presenter = IOSNativeSelectableTextMenuPresenterFake()
    let handler = IOSNativeSelectableTextMenuHandler(presenter: presenter)

    handler.dispose()

    XCTAssertTrue(presenter.isDisposed)
  }

  private func request(sessionIdentifier: Int64) -> NativeSelectableTextMenuRequestMessage {
    NativeSelectableTextMenuRequestMessage(
      sessionIdentifier: sessionIdentifier,
      selectionRectangle: NativeSelectableTextRectangleMessage(
        left: 10,
        top: 20,
        right: 30,
        bottom: 40
      ),
      primaryAnchor: NativeSelectableTextPointMessage(dx: 20, dy: 20),
      items: [NativeSelectableTextMenuItemMessage(identifier: 1, label: "Copy")]
    )
  }

  private func geometry(_ values: Double...) -> FlutterStandardTypedData {
    values.withUnsafeBytes { bytes in
      FlutterStandardTypedData(
        float64: Data(bytes: bytes.baseAddress!, count: bytes.count)
      )
    }
  }
}
