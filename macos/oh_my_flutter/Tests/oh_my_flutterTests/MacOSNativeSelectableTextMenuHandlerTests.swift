import AppKit
import FlutterMacOS
import XCTest

@preconcurrency @testable import oh_my_flutter

final class MacOSNativeSelectableTextMenuHandlerTests: XCTestCase, @unchecked Sendable {
  func testWhenNoFlutterViewIsAttachedItShouldRejectPresentation() {
    let handler = makeHandler()

    let didShow = handler.show(request: request(sessionIdentifier: 11))

    XCTAssertFalse(didShow)
  }

  func testWhenTheFlutterViewUsesAppKitCoordinatesItShouldInvertTheAnchorYAxis() {
    let handler = makeHandler()
    let view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))

    let point = handler.point(
      from: NativeSelectableTextPointMessage(dx: 12, dy: 18),
      in: view
    )

    XCTAssertEqual(point, NSPoint(x: 12, y: 82))
  }

  func testWhenBuildingAMenuItShouldPreserveLocalizedActionOrder() {
    let handler = makeHandler()

    let titles = handler.makeMenu(for: request(sessionIdentifier: 12)).items.map(\.title)

    XCTAssertEqual(titles, ["Copy", "Select All"])
  }

  func testWhenAnUpdateBelongsToNoVisibleSessionItShouldRejectIt() {
    let handler = makeHandler()

    let didUpdate = handler.update(request: request(sessionIdentifier: 13))

    XCTAssertFalse(didUpdate)
  }

  func testWhenAnUpdateMatchesThePresentedSessionItShouldAcceptIt() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    let view = NSView(frame: window.contentView?.bounds ?? .zero)
    window.contentView = view
    let handler = MacOSNativeSelectableTextMenuHandler(
      viewProvider: { view },
      flutterApi: MacOSNativeSelectableTextMenuFlutterApiSpy()
    )

    _ = handler.show(request: request(sessionIdentifier: 14))
    let didUpdate = handler.update(request: request(sessionIdentifier: 14))
    handler.dispose()

    withExtendedLifetime(window) {
      XCTAssertTrue(didUpdate)
    }
  }

  @MainActor
  func testWhenTheViewDetachesBeforeQueuedPresentationItShouldDismissAndRejectStaleUpdates()
    async
  {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    let view = NSView(frame: window.contentView?.bounds ?? .zero)
    window.contentView = view
    let flutterApi = MacOSNativeSelectableTextMenuFlutterApiSpy()
    let dismissal = expectation(description: "unavailable queued presentation dismissed")
    flutterApi.onDismissalDelivery = {
      dismissal.fulfill()
    }
    var presentationCount = 0
    let handler = MacOSNativeSelectableTextMenuHandler(
      viewProvider: { view },
      flutterApi: flutterApi,
      presentMenu: { _, _, _ in
        presentationCount += 1
        return true
      }
    )

    let didShow = handler.show(request: request(sessionIdentifier: 34))
    window.contentView = nil
    await fulfillment(of: [dismissal], timeout: 1)
    window.contentView = view
    let didUpdate = handler.update(request: request(sessionIdentifier: 34))
    handler.dispose()

    withExtendedLifetime(window) {
      XCTAssertTrue(
        didShow
          && !didUpdate
          && presentationCount == 0
          && flutterApi.events == ["dismissal:34:false"]
      )
    }
  }

  @MainActor
  func testWhenCompactGeometryHasSixDoublesItShouldRepositionWithoutRebuildingItems() async {
    let fixture = makePresentedFixture(sessionIdentifier: 26, expectsUpdate: true)
    await fulfillment(of: [fixture.firstPresentation], timeout: 1)

    let didUpdate = fixture.handler.updateGeometry(
      sessionIdentifier: 26,
      geometry: geometry(12, 22, 34, 44, 26, 28)
    )
    await fulfillment(of: [fixture.secondPresentation!], timeout: 1)
    let presentation = (
      fixture.presentationSpy.menus[0] === fixture.presentationSpy.menus[1],
      fixture.presentationSpy.menus[1].items.map(\.title),
      fixture.presentationSpy.points[1]
    )
    fixture.handler.dispose()

    withExtendedLifetime(fixture.window) {
      XCTAssertTrue(
        didUpdate
          && presentation.0
          && presentation.1 == ["Copy", "Select All"]
          && presentation.2 == NSPoint(x: 26, y: 72)
      )
    }
  }

  @MainActor
  func testWhenCompactGeometryIsNotExactlySixFloat64ValuesItShouldRejectIt() async {
    let shortFixture = makePresentedFixture(sessionIdentifier: 27)
    let byteFixture = makePresentedFixture(sessionIdentifier: 28)
    await fulfillment(
      of: [shortFixture.firstPresentation, byteFixture.firstPresentation],
      timeout: 1
    )

    let shortResult = shortFixture.handler.updateGeometry(
      sessionIdentifier: 27,
      geometry: geometry(10, 20, 30, 40, 20)
    )
    let byteResult = byteFixture.handler.updateGeometry(
      sessionIdentifier: 28,
      geometry: byteGeometry(10, 20, 30, 40, 20, 20)
    )
    shortFixture.handler.dispose()
    byteFixture.handler.dispose()

    withExtendedLifetime((shortFixture.window, byteFixture.window)) {
      XCTAssertEqual([shortResult, byteResult], [false, false])
    }
  }

  @MainActor
  func testWhenCompactGeometryBelongsToAnotherSessionItShouldKeepTheCurrentSession() async {
    let fixture = makePresentedFixture(sessionIdentifier: 29, expectsUpdate: true)
    await fulfillment(of: [fixture.firstPresentation], timeout: 1)

    let staleResult = fixture.handler.updateGeometry(
      sessionIdentifier: 999,
      geometry: geometry(12, 22, 34, 44, 26, 28)
    )
    let currentResult = fixture.handler.updateGeometry(
      sessionIdentifier: 29,
      geometry: geometry(14, 24, 36, 46, 28, 30)
    )
    await fulfillment(of: [fixture.secondPresentation!], timeout: 1)
    fixture.handler.dispose()

    withExtendedLifetime(fixture.window) {
      XCTAssertEqual([staleResult, currentResult], [false, true])
    }
  }

  @MainActor
  func testWhenCompactGeometryIsNotFiniteOrIsInvertedItShouldRejectIt() async {
    let nonFiniteResult = await compactGeometryResult(
      sessionIdentifier: 30,
      coordinates: [10, 20, 30, 40, .infinity, 20]
    )
    let invertedResult = await compactGeometryResult(
      sessionIdentifier: 31,
      coordinates: [30, 20, 10, 40, 20, 20]
    )

    XCTAssertEqual([nonFiniteResult, invertedResult], [false, false])
  }

  @MainActor
  func testWhenTheAttachedViewLeavesItsWindowItShouldRejectCompactGeometry() async {
    let fixture = makePresentedFixture(sessionIdentifier: 32)
    await fulfillment(of: [fixture.firstPresentation], timeout: 1)

    fixture.window.contentView = nil
    let didUpdate = fixture.handler.updateGeometry(
      sessionIdentifier: 32,
      geometry: geometry(12, 22, 34, 44, 26, 28)
    )
    fixture.handler.dispose()

    withExtendedLifetime(fixture.window) {
      XCTAssertFalse(didUpdate)
    }
  }

  @MainActor
  func testWhenCompactGeometryArrivesOffMainThreadItShouldRepositionOnMainThread() async {
    let fixture = makePresentedFixture(sessionIdentifier: 33, expectsUpdate: true)
    await fulfillment(of: [fixture.firstPresentation], timeout: 1)
    let updateFinished = expectation(description: "geometry updated")

    DispatchQueue.global().async {
      _ = fixture.handler.updateGeometry(
        sessionIdentifier: 33,
        geometry: self.geometry(12, 22, 34, 44, 26, 28)
      )
      updateFinished.fulfill()
    }
    await fulfillment(
      of: [updateFinished, fixture.secondPresentation!],
      timeout: 1
    )
    let presentationsWereOnMainThread = fixture.presentationSpy.presentationsWereOnMainThread
    fixture.handler.dispose()

    withExtendedLifetime(fixture.window) {
      XCTAssertEqual(presentationsWereOnMainThread, [true, true])
    }
  }

  @MainActor
  func testWhenAnUpdateIsIdenticalItShouldKeepTheExistingMenuPresentation() async {
    let fixture = makePresentedFixture(sessionIdentifier: 21)
    await fulfillment(of: [fixture.firstPresentation], timeout: 1)

    _ = fixture.handler.update(request: request(sessionIdentifier: 21))
    await yieldToMainActor()
    let presentationCount = fixture.presentationSpy.menus.count
    fixture.handler.dispose()

    withExtendedLifetime(fixture.window) {
      XCTAssertEqual(presentationCount, 1)
    }
  }

  @MainActor
  func testWhenOnlyGeometryChangesItShouldReuseTheExistingMenuItems() async {
    let fixture = makePresentedFixture(sessionIdentifier: 22, expectsUpdate: true)
    await fulfillment(of: [fixture.firstPresentation], timeout: 1)

    _ = fixture.handler.update(
      request: request(
        sessionIdentifier: 22,
        rectangle: NativeSelectableTextRectangleMessage(
          left: 12,
          top: 22,
          right: 34,
          bottom: 44
        ),
        anchor: NativeSelectableTextPointMessage(dx: 22, dy: 22)
      )
    )
    fixture.handler.menuDidClose(fixture.presentationSpy.menus[0])
    await fulfillment(of: [fixture.secondPresentation!], timeout: 1)
    let reusedMenu = fixture.presentationSpy.menus[0] === fixture.presentationSpy.menus[1]
    fixture.handler.dispose()

    withExtendedLifetime(fixture.window) {
      XCTAssertTrue(reusedMenu)
    }
  }

  @MainActor
  func testWhenGeometryUpdatesCoalesceItShouldStillReuseTheExistingMenuItems() async {
    let fixture = makePresentedFixture(sessionIdentifier: 24, expectsUpdate: true)
    await fulfillment(of: [fixture.firstPresentation], timeout: 1)

    _ = fixture.handler.update(
      request: request(
        sessionIdentifier: 24,
        anchor: NativeSelectableTextPointMessage(dx: 22, dy: 22)
      )
    )
    _ = fixture.handler.update(
      request: request(
        sessionIdentifier: 24,
        anchor: NativeSelectableTextPointMessage(dx: 24, dy: 24)
      )
    )
    fixture.handler.menuDidClose(fixture.presentationSpy.menus[0])
    await fulfillment(of: [fixture.secondPresentation!], timeout: 1)
    let reusedMenu = fixture.presentationSpy.menus[0] === fixture.presentationSpy.menus[1]
    fixture.handler.dispose()

    withExtendedLifetime(fixture.window) {
      XCTAssertTrue(reusedMenu)
    }
  }

  @MainActor
  func testWhenAReusedMenusOldCloseArrivesLateItShouldKeepTheUpdatedSession() async {
    let fixture = makePresentedFixture(sessionIdentifier: 25, expectsUpdate: true)
    await fulfillment(of: [fixture.firstPresentation], timeout: 1)

    _ = fixture.handler.update(
      request: request(
        sessionIdentifier: 25,
        anchor: NativeSelectableTextPointMessage(dx: 22, dy: 22)
      )
    )
    await fulfillment(of: [fixture.secondPresentation!], timeout: 1)
    fixture.handler.menuDidClose(fixture.presentationSpy.menus[0])
    let didUpdate = fixture.handler.update(
      request: request(
        sessionIdentifier: 25,
        anchor: NativeSelectableTextPointMessage(dx: 24, dy: 24)
      )
    )
    fixture.handler.dispose()

    withExtendedLifetime(fixture.window) {
      XCTAssertTrue(didUpdate)
    }
  }

  @MainActor
  func testWhenMenuItemsChangeItShouldBuildTheUpdatedActions() async {
    let fixture = makePresentedFixture(sessionIdentifier: 23, expectsUpdate: true)
    await fulfillment(of: [fixture.firstPresentation], timeout: 1)

    _ = fixture.handler.update(
      request: request(sessionIdentifier: 23, labels: ["Copy", "Look Up"])
    )
    fixture.handler.menuDidClose(fixture.presentationSpy.menus[0])
    await fulfillment(of: [fixture.secondPresentation!], timeout: 1)
    let updatedTitles = fixture.presentationSpy.menus[1].items.map(\.title)
    fixture.handler.dispose()

    withExtendedLifetime(fixture.window) {
      XCTAssertEqual(updatedTitles, ["Copy", "Look Up"])
    }
  }

  @MainActor
  func testWhenAnOldMenuClosesDuringAnUpdateItShouldPresentTheUpdatedSession() async {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    let view = NSView(frame: window.contentView?.bounds ?? .zero)
    window.contentView = view
    let firstPresentation = expectation(description: "initial menu presented")
    let secondPresentation = expectation(description: "updated menu presented")
    var presentedMenus: [NSMenu] = []
    let handler = MacOSNativeSelectableTextMenuHandler(
      viewProvider: { view },
      flutterApi: MacOSNativeSelectableTextMenuFlutterApiSpy(),
      presentMenu: { menu, _, _ in
        presentedMenus.append(menu)
        if presentedMenus.count == 1 {
          firstPresentation.fulfill()
        } else if presentedMenus.count == 2 {
          secondPresentation.fulfill()
        }
        return true
      }
    )

    _ = handler.show(request: request(sessionIdentifier: 19))
    await fulfillment(of: [firstPresentation], timeout: 1)
    _ = handler.update(
      request: request(
        sessionIdentifier: 19,
        anchor: NativeSelectableTextPointMessage(dx: 21, dy: 21)
      )
    )
    handler.menuDidClose(presentedMenus[0])
    await fulfillment(of: [secondPresentation], timeout: 1)
    let presentationCount = presentedMenus.count
    handler.dispose()

    withExtendedLifetime(window) {
      XCTAssertEqual(presentationCount, 2)
    }
  }

  func testWhenAnUpdateBelongsToAnotherPresentedSessionItShouldRejectIt() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    let view = NSView(frame: window.contentView?.bounds ?? .zero)
    window.contentView = view
    let handler = MacOSNativeSelectableTextMenuHandler(
      viewProvider: { view },
      flutterApi: MacOSNativeSelectableTextMenuFlutterApiSpy()
    )

    _ = handler.show(request: request(sessionIdentifier: 15))
    let didUpdate = handler.update(request: request(sessionIdentifier: 16))
    handler.dispose()

    withExtendedLifetime(window) {
      XCTAssertFalse(didUpdate)
    }
  }

  @MainActor
  func testWhenACurrentUpdateIsRejectedItShouldPreserveTheSelectionForFallback() async {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    let view = NSView(frame: window.contentView?.bounds ?? .zero)
    window.contentView = view
    let flutterApi = MacOSNativeSelectableTextMenuFlutterApiSpy()
    let presentation = expectation(description: "native menu presented")
    var presentedMenu: NSMenu?
    let handler = MacOSNativeSelectableTextMenuHandler(
      viewProvider: { view },
      flutterApi: flutterApi,
      presentMenu: { menu, _, _ in
        presentedMenu = menu
        presentation.fulfill()
        return true
      }
    )

    _ = handler.show(request: request(sessionIdentifier: 20))
    await fulfillment(of: [presentation], timeout: 1)
    let didUpdate = handler.update(
      request: request(sessionIdentifier: 20, labels: [" \n "])
    )
    handler.menuDidClose(presentedMenu!)
    for _ in 0..<10 {
      await Task.yield()
    }
    handler.dispose()

    withExtendedLifetime(window) {
      XCTAssertTrue(!didUpdate && flutterApi.dismissals.isEmpty)
    }
  }

  func testWhenAnActionLabelContainsOnlyWhitespaceItShouldRejectTheRequest() {
    let handler = makeHandler()

    let isValid = handler.isValid(
      request: request(sessionIdentifier: 17, labels: ["Copy", " \n "])
    )

    XCTAssertFalse(isValid)
  }

  func testWhenDisposedItShouldRejectAnotherPresentation() {
    let handler = makeHandler()

    handler.dispose()
    let didShow = handler.show(request: request(sessionIdentifier: 18))

    XCTAssertFalse(didShow)
  }

  func testWhenDismissalBelongsToNoMenuSessionItShouldIgnoreIt() async {
    let flutterApi = MacOSNativeSelectableTextMenuFlutterApiSpy()
    let handler = MacOSNativeSelectableTextMenuHandler(
      viewProvider: { nil },
      flutterApi: flutterApi
    )

    handler.completeDismissal(of: NSMenu())
    await Task.yield()

    XCTAssertTrue(flutterApi.dismissals.isEmpty)
  }

  private func makeHandler() -> MacOSNativeSelectableTextMenuHandler {
    MacOSNativeSelectableTextMenuHandler(
      viewProvider: { nil },
      flutterApi: MacOSNativeSelectableTextMenuFlutterApiSpy()
    )
  }

  @MainActor
  private func makePresentedFixture(
    sessionIdentifier: Int64,
    expectsUpdate: Bool = false
  ) -> (
    window: NSWindow,
    handler: MacOSNativeSelectableTextMenuHandler,
    presentationSpy: MacOSNativeSelectableTextMenuPresentationSpy,
    firstPresentation: XCTestExpectation,
    secondPresentation: XCTestExpectation?
  ) {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    let view = NSView(frame: window.contentView?.bounds ?? .zero)
    window.contentView = view
    let presentationSpy = MacOSNativeSelectableTextMenuPresentationSpy(
      testCase: self,
      expectsUpdate: expectsUpdate
    )
    let handler = MacOSNativeSelectableTextMenuHandler(
      viewProvider: { view },
      flutterApi: MacOSNativeSelectableTextMenuFlutterApiSpy(),
      presentMenu: { menu, point, _ in
        presentationSpy.present(menu: menu, at: point)
      }
    )
    _ = handler.show(request: request(sessionIdentifier: sessionIdentifier))
    return (
      window,
      handler,
      presentationSpy,
      presentationSpy.firstPresentation,
      presentationSpy.secondPresentation
    )
  }

  private func yieldToMainActor() async {
    for _ in 0..<10 {
      await Task.yield()
    }
  }

  @MainActor
  private func compactGeometryResult(
    sessionIdentifier: Int64,
    coordinates: [Double]
  ) async -> Bool {
    let fixture = makePresentedFixture(sessionIdentifier: sessionIdentifier)
    await fulfillment(of: [fixture.firstPresentation], timeout: 1)
    let result = fixture.handler.updateGeometry(
      sessionIdentifier: sessionIdentifier,
      geometry: geometry(coordinates)
    )
    fixture.handler.dispose()
    return withExtendedLifetime(fixture.window) { result }
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
    labels: [String] = ["Copy", "Select All"],
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
        NativeSelectableTextMenuItemMessage(identifier: Int64(index + 1), label: label)
      }
    )
  }
}
