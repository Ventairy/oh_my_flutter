import AppKit
import XCTest

internal final class MacOSNativeSelectableTextMenuPresentationSpy: @unchecked Sendable {
  internal let firstPresentation: XCTestExpectation
  internal let secondPresentation: XCTestExpectation?
  internal private(set) var menus: [NSMenu] = []
  internal private(set) var points: [NSPoint] = []
  internal private(set) var presentationsWereOnMainThread: [Bool] = []

  internal init(testCase: XCTestCase, expectsUpdate: Bool) {
    firstPresentation = testCase.expectation(description: "initial menu presented")
    secondPresentation =
      expectsUpdate
      ? testCase.expectation(description: "updated menu presented")
      : nil
  }

  @MainActor
  internal func present(menu: NSMenu, at point: NSPoint) -> Bool {
    menus.append(menu)
    points.append(point)
    presentationsWereOnMainThread.append(Thread.isMainThread)
    if menus.count == 1 {
      firstPresentation.fulfill()
    } else if menus.count == 2 {
      secondPresentation?.fulfill()
    }
    return true
  }
}
