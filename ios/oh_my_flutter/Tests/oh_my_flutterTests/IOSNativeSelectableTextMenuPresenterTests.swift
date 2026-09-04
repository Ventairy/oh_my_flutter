import Flutter
import UIKit
import XCTest

@preconcurrency @testable import oh_my_flutter

@available(iOS 16.0, *)
final class IOSNativeSelectableTextMenuPresenterTests: XCTestCase, @unchecked Sendable {
  func testWhenConvertingAnAnchorItShouldPreserveFlutterViewCoordinates() {
    let presenter = makePresenter()
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    view.bounds.origin = CGPoint(x: 4, y: 6)

    let point = presenter.point(
      from: NativeSelectableTextPointMessage(dx: 12, dy: 18),
      in: view
    )

    XCTAssertEqual(point, CGPoint(x: 16, y: 24))
  }

  func testWhenConvertingASelectionItShouldPreserveItsGlyphBounds() {
    let presenter = makePresenter()
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    view.bounds.origin = CGPoint(x: 4, y: 6)

    let rectangle = presenter.rectangle(
      from: NativeSelectableTextRectangleMessage(
        left: 10,
        top: 20,
        right: 40,
        bottom: 50
      ),
      in: view
    )

    XCTAssertEqual(rectangle, CGRect(x: 14, y: 26, width: 30, height: 30))
  }

  func testWhenDismissalIsStaleItShouldNotNotifyFlutter() async {
    let flutterApi = IOSNativeSelectableTextMenuFlutterApiSpy()
    let presenter = IOSNativeSelectableTextMenuPresenter(
      viewProvider: { nil },
      flutterApi: flutterApi
    )

    presenter.completeDismissal(sessionIdentifier: 99)
    await Task.yield()

    XCTAssertTrue(flutterApi.dismissals.isEmpty)
  }

  func testWhenAnActionLabelContainsOnlyWhitespaceItShouldRejectTheRequest() {
    let presenter = makePresenter()

    let isValid = presenter.isValid(
      request: request(sessionIdentifier: 100, labels: ["Copy", " \n "])
    )

    XCTAssertFalse(isValid)
  }

  func testWhenAnUpdateMatchesThePresentedSessionItShouldAcceptIt() {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    let view = UIView(frame: window.bounds)
    window.addSubview(view)
    let presenter = IOSNativeSelectableTextMenuPresenter(
      viewProvider: { view },
      flutterApi: IOSNativeSelectableTextMenuFlutterApiSpy()
    )

    _ = presenter.show(request: request(sessionIdentifier: 101))
    let didUpdate = presenter.update(request: request(sessionIdentifier: 101))
    presenter.dispose()

    withExtendedLifetime(window) {
      XCTAssertTrue(didUpdate)
    }
  }

  func testWhenAnUpdateIsIdenticalItShouldNotRefreshTheVisibleMenu() {
    let fixture = makePresentedFixture(sessionIdentifier: 106)

    _ = fixture.presenter.update(request: request(sessionIdentifier: 106))
    let calls = (
      fixture.interaction.reloadVisibleMenuCallCount,
      fixture.interaction.updateVisibleMenuPositionCallCount
    )
    fixture.presenter.dispose()

    withExtendedLifetime(fixture.window) {
      XCTAssertEqual(calls.0 + calls.1, 0)
    }
  }

  func testWhenOnlySelectionGeometryChangesItShouldOnlyUpdateMenuPosition() {
    let fixture = makePresentedFixture(sessionIdentifier: 107)

    _ = fixture.presenter.update(
      request: request(
        sessionIdentifier: 107,
        rectangle: NativeSelectableTextRectangleMessage(
          left: 12,
          top: 22,
          right: 34,
          bottom: 44
        ),
        anchor: NativeSelectableTextPointMessage(dx: 22, dy: 22)
      )
    )
    let calls = (
      fixture.interaction.reloadVisibleMenuCallCount,
      fixture.interaction.updateVisibleMenuPositionCallCount
    )
    fixture.presenter.dispose()

    withExtendedLifetime(fixture.window) {
      XCTAssertTrue(calls == (0, 1))
    }
  }

  func testWhenOnlyMenuItemsChangeItShouldOnlyReloadTheVisibleMenu() {
    let fixture = makePresentedFixture(sessionIdentifier: 108)

    _ = fixture.presenter.update(
      request: request(sessionIdentifier: 108, labels: ["Copy", "Select All"])
    )
    let calls = (
      fixture.interaction.reloadVisibleMenuCallCount,
      fixture.interaction.updateVisibleMenuPositionCallCount
    )
    fixture.presenter.dispose()

    withExtendedLifetime(fixture.window) {
      XCTAssertTrue(calls == (1, 0))
    }
  }

  func testWhenCompactGeometryHasSixDoublesItShouldOnlyUpdateTheVisiblePosition() {
    let fixture = makePresentedFixture(sessionIdentifier: 109)

    let didUpdate = fixture.presenter.updateGeometry(
      sessionIdentifier: 109,
      geometry: geometry(12, 22, 34, 44, 26, 28)
    )
    let targetRectangle = fixture.presenter.editMenuInteraction(
      fixture.interaction,
      targetRectFor: UIEditMenuConfiguration(
        identifier: NSNumber(value: 109),
        sourcePoint: .zero
      )
    )
    let calls = (
      fixture.interaction.reloadVisibleMenuCallCount,
      fixture.interaction.updateVisibleMenuPositionCallCount
    )
    fixture.presenter.dispose()

    withExtendedLifetime(fixture.window) {
      XCTAssertTrue(
        didUpdate
          && targetRectangle == CGRect(x: 12, y: 22, width: 22, height: 22)
          && calls == (0, 1)
      )
    }
  }

  func testWhenCompactGeometryIsNotExactlySixFloat64ValuesItShouldRejectIt() {
    let shortFixture = makePresentedFixture(sessionIdentifier: 110)
    let byteFixture = makePresentedFixture(sessionIdentifier: 111)

    let shortResult = shortFixture.presenter.updateGeometry(
      sessionIdentifier: 110,
      geometry: geometry(10, 20, 30, 40, 20)
    )
    let byteResult = byteFixture.presenter.updateGeometry(
      sessionIdentifier: 111,
      geometry: byteGeometry(10, 20, 30, 40, 20, 20)
    )
    shortFixture.presenter.dispose()
    byteFixture.presenter.dispose()

    withExtendedLifetime((shortFixture.window, byteFixture.window)) {
      XCTAssertEqual([shortResult, byteResult], [false, false])
    }
  }

  func testWhenCompactGeometryBelongsToAnotherSessionItShouldKeepTheCurrentSession() {
    let fixture = makePresentedFixture(sessionIdentifier: 112)

    let staleResult = fixture.presenter.updateGeometry(
      sessionIdentifier: 999,
      geometry: geometry(12, 22, 34, 44, 26, 28)
    )
    let currentResult = fixture.presenter.updateGeometry(
      sessionIdentifier: 112,
      geometry: geometry(14, 24, 36, 46, 28, 30)
    )
    fixture.presenter.dispose()

    withExtendedLifetime(fixture.window) {
      XCTAssertEqual([staleResult, currentResult], [false, true])
    }
  }

  func testWhenCompactGeometryIsNotFiniteOrIsInvertedItShouldRejectIt() {
    let invalidCoordinates: [[Double]] = [
      [.nan, 20, 30, 40, 20, 20],
      [10, 20, 30, 40, .infinity, 20],
      [30, 20, 10, 40, 20, 20],
      [10, 40, 30, 20, 20, 20],
    ]

    let results = invalidCoordinates.enumerated().map { index, coordinates in
      let fixture = makePresentedFixture(sessionIdentifier: Int64(113 + index))
      let result = fixture.presenter.updateGeometry(
        sessionIdentifier: Int64(113 + index),
        geometry: geometry(coordinates)
      )
      fixture.presenter.dispose()
      return result
    }

    XCTAssertEqual(results, [false, false, false, false])
  }

  func testWhenTheAttachedViewLeavesItsWindowItShouldRejectCompactGeometry() {
    let fixture = makePresentedFixture(sessionIdentifier: 117)

    fixture.view.removeFromSuperview()
    let didUpdate = fixture.presenter.updateGeometry(
      sessionIdentifier: 117,
      geometry: geometry(12, 22, 34, 44, 26, 28)
    )
    fixture.presenter.dispose()

    withExtendedLifetime(fixture.window) {
      XCTAssertFalse(didUpdate)
    }
  }

  @MainActor
  func testWhenCompactGeometryArrivesOffMainThreadItShouldRepositionOnMainThread() async {
    let fixture = makePresentedFixture(sessionIdentifier: 118)
    let completion = expectation(description: "geometry updated")

    DispatchQueue.global().async {
      _ = fixture.presenter.updateGeometry(
        sessionIdentifier: 118,
        geometry: self.geometry(12, 22, 34, 44, 26, 28)
      )
      completion.fulfill()
    }
    await fulfillment(of: [completion], timeout: 1)
    let positionUpdatesWereOnMainThread = fixture.interaction.positionUpdatesWereOnMainThread
    fixture.presenter.dispose()

    withExtendedLifetime(fixture.window) {
      XCTAssertEqual(positionUpdatesWereOnMainThread, [true])
    }
  }

  func testWhenAnUpdateBelongsToAnotherSessionItShouldRejectIt() {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    let view = UIView(frame: window.bounds)
    window.addSubview(view)
    let presenter = IOSNativeSelectableTextMenuPresenter(
      viewProvider: { view },
      flutterApi: IOSNativeSelectableTextMenuFlutterApiSpy()
    )

    _ = presenter.show(request: request(sessionIdentifier: 102))
    let didUpdate = presenter.update(request: request(sessionIdentifier: 103))
    presenter.dispose()

    withExtendedLifetime(window) {
      XCTAssertFalse(didUpdate)
    }
  }

  @MainActor
  func testWhenACurrentUpdateIsRejectedItShouldPreserveTheSelectionForFallback() async {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    let view = UIView(frame: window.bounds)
    window.addSubview(view)
    let flutterApi = IOSNativeSelectableTextMenuFlutterApiSpy()
    let presenter = IOSNativeSelectableTextMenuPresenter(
      viewProvider: { view },
      flutterApi: flutterApi
    )

    _ = presenter.show(request: request(sessionIdentifier: 105))
    let didUpdate = presenter.update(
      request: request(sessionIdentifier: 105, labels: [" \n "])
    )
    presenter.completeDismissal(sessionIdentifier: 105)
    for _ in 0..<10 {
      await Task.yield()
    }
    presenter.dispose()

    withExtendedLifetime(window) {
      XCTAssertTrue(!didUpdate && flutterApi.dismissals.isEmpty)
    }
  }

  func testWhenDisposedItShouldRejectAnotherPresentation() {
    let presenter = makePresenter()

    presenter.dispose()
    let didShow = presenter.show(request: request(sessionIdentifier: 104))

    XCTAssertFalse(didShow)
  }

  private func makePresenter() -> IOSNativeSelectableTextMenuPresenter {
    IOSNativeSelectableTextMenuPresenter(
      viewProvider: { nil },
      flutterApi: IOSNativeSelectableTextMenuFlutterApiSpy()
    )
  }

  private func makePresentedFixture(
    sessionIdentifier: Int64
  ) -> (
    window: UIWindow,
    view: UIView,
    presenter: IOSNativeSelectableTextMenuPresenter,
    interaction: IOSNativeSelectableTextMenuInteractionSpy
  ) {
    let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    let view = UIView(frame: window.bounds)
    window.addSubview(view)
    var interaction: IOSNativeSelectableTextMenuInteractionSpy?
    let presenter = IOSNativeSelectableTextMenuPresenter(
      test: { view },
      flutterApi: IOSNativeSelectableTextMenuFlutterApiSpy(),
      interactionFactory: { delegate in
        let createdInteraction = IOSNativeSelectableTextMenuInteractionSpy(delegate: delegate)
        interaction = createdInteraction
        return createdInteraction
      }
    )
    _ = presenter.show(request: request(sessionIdentifier: sessionIdentifier))
    return (window, view, presenter, interaction!)
  }

  private func geometry(_ values: Double...) -> FlutterStandardTypedData {
    geometry(values)
  }

  private func geometry(_ values: [Double]) -> FlutterStandardTypedData {
    values.withUnsafeBytes { bytes in
      FlutterStandardTypedData(
        float64: Data(bytes: bytes.baseAddress!, count: bytes.count)
      )
    }
  }

  private func byteGeometry(_ values: Double...) -> FlutterStandardTypedData {
    values.withUnsafeBytes { bytes in
      FlutterStandardTypedData(
        bytes: Data(bytes: bytes.baseAddress!, count: bytes.count)
      )
    }
  }

  private func request(
    sessionIdentifier: Int64,
    labels: [String] = ["Copy"],
    rectangle: NativeSelectableTextRectangleMessage = NativeSelectableTextRectangleMessage(
      left: 10,
      top: 20,
      right: 30,
      bottom: 40
    ),
    anchor: NativeSelectableTextPointMessage = NativeSelectableTextPointMessage(dx: 20, dy: 20)
  ) -> NativeSelectableTextMenuRequestMessage {
    NativeSelectableTextMenuRequestMessage(
      sessionIdentifier: sessionIdentifier,
      selectionRectangle: rectangle,
      primaryAnchor: anchor,
      items: labels.enumerated().map { index, label in
        NativeSelectableTextMenuItemMessage(identifier: Int64(index), label: label)
      }
    )
  }
}
