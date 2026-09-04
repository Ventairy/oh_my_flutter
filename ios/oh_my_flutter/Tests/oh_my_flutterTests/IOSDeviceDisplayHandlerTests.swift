import UIKit
import XCTest

@testable import oh_my_flutter

final class IOSDeviceDisplayHandlerTests: XCTestCase {
  func testWhenConcentricCornersAreUnavailableItShouldReturnNilWithoutReadingTheWindow() throws {
    var readCount = 0
    let handler = IOSDeviceDisplayHandler(
      viewProvider: { nil },
      supportsConcentricCorners: { false },
      cornerRadiiReader: { _ in
        readCount += 1
        return DeviceDisplayCornerRadiiMessage(
          topLeft: 1,
          topRight: 1,
          bottomRight: 1,
          bottomLeft: 1
        )
      }
    )

    let result = try handler.getCornerRadii(geometry: placeholderGeometry)

    XCTAssertNil(result)
    XCTAssertEqual(readCount, 0)
  }

  func testWhenTheFlutterViewIsUnavailableItShouldReturnNil() throws {
    let handler = IOSDeviceDisplayHandler(
      viewProvider: { nil },
      supportsConcentricCorners: { true }
    )

    XCTAssertNil(try handler.getCornerRadii(geometry: placeholderGeometry))
  }

  func testWhenTheFlutterViewIsDetachedItShouldReturnNil() throws {
    let view = UIView(frame: UIScreen.main.bounds)
    let handler = IOSDeviceDisplayHandler(
      viewProvider: { view },
      supportsConcentricCorners: { true }
    )

    XCTAssertNil(try handler.getCornerRadii(geometry: placeholderGeometry))
  }

  func testWhenFlutterGeometryDoesNotMatchTheNativeViewItShouldReturnNil() throws {
    let (window, view) = makeWindow()
    var geometry = makeGeometry(view: view, window: window)
    geometry.viewWidth += 2
    let handler = IOSDeviceDisplayHandler(
      viewProvider: { view },
      supportsConcentricCorners: { true }
    )

    XCTAssertNil(try handler.getCornerRadii(geometry: geometry))
  }

  func testWhenTheFlutterViewDoesNotFillTheWindowItShouldReturnNil() throws {
    let (window, _) = makeWindow()
    let view = UIView(frame: window.bounds.insetBy(dx: 20, dy: 20))
    window.addSubview(view)
    let handler = IOSDeviceDisplayHandler(
      viewProvider: { view },
      supportsConcentricCorners: { true }
    )

    XCTAssertNil(
      try handler.getCornerRadii(
        geometry: makeGeometry(view: view, window: window)
      )
    )
  }

  func testWhenTheWindowDoesNotFillTheScreenItShouldReturnNil() throws {
    let screenBounds = UIScreen.main.bounds
    let window = UIWindow(frame: screenBounds.insetBy(dx: 20, dy: 20))
    let viewController = UIViewController()
    window.rootViewController = viewController
    window.makeKeyAndVisible()
    viewController.loadViewIfNeeded()
    window.layoutIfNeeded()
    addTeardownBlock { window.isHidden = true }
    let handler = IOSDeviceDisplayHandler(
      viewProvider: { viewController.view },
      supportsConcentricCorners: { true }
    )

    XCTAssertNil(
      try handler.getCornerRadii(
        geometry: makeGeometry(view: viewController.view, window: window)
      )
    )
  }

  func testWhenTheValidatedWindowProvidesRadiiItShouldReturnEveryPhysicalValue() throws {
    let (window, view) = makeWindow()
    let expected = DeviceDisplayCornerRadiiMessage(
      topLeft: 10,
      topRight: 20,
      bottomRight: 30,
      bottomLeft: 40
    )
    let handler = IOSDeviceDisplayHandler(
      viewProvider: { view },
      supportsConcentricCorners: { true },
      cornerRadiiReader: { _ in expected }
    )

    let result = try handler.getCornerRadii(
      geometry: makeGeometry(view: view, window: window)
    )

    XCTAssertEqual(result, expected)
  }

  func testWhenIOS26ReadsPublicCornersItShouldReturnFiniteNonnegativeRadii() throws {
    guard #available(iOS 26.0, *) else {
      throw XCTSkip("Public concentric display corners require iOS 26.")
    }
    let (window, view) = makeWindow()
    let handler = IOSDeviceDisplayHandler(viewProvider: { view })

    let result = try XCTUnwrap(
      handler.getCornerRadii(
        geometry: makeGeometry(view: view, window: window)
      )
    )
    let values = [
      result.topLeft,
      result.topRight,
      result.bottomRight,
      result.bottomLeft,
    ]

    XCTAssertTrue(values.allSatisfy { $0.isFinite && $0 >= 0 })
  }

  func testWhenIOS26ReadsPublicCornersItShouldRemoveItsProbe() throws {
    guard #available(iOS 26.0, *) else {
      throw XCTSkip("Public concentric display corners require iOS 26.")
    }
    let (window, view) = makeWindow()
    let handler = IOSDeviceDisplayHandler(viewProvider: { view })
    let subviewCount = window.subviews.count

    _ = try handler.getCornerRadii(
      geometry: makeGeometry(view: view, window: window)
    )

    XCTAssertEqual(window.subviews.count, subviewCount)
  }

  private var placeholderGeometry: DeviceDisplayGeometryMessage {
    DeviceDisplayGeometryMessage(
      displayWidth: 1,
      displayHeight: 1,
      viewWidth: 1,
      viewHeight: 1
    )
  }

  private func makeWindow() -> (window: UIWindow, view: UIView) {
    let window = UIWindow(frame: UIScreen.main.bounds)
    let viewController = UIViewController()
    window.rootViewController = viewController
    window.makeKeyAndVisible()
    viewController.loadViewIfNeeded()
    window.layoutIfNeeded()
    addTeardownBlock { window.isHidden = true }
    return (window, viewController.view)
  }

  private func makeGeometry(
    view: UIView,
    window: UIWindow
  ) -> DeviceDisplayGeometryMessage {
    let scale = window.screen.scale
    return DeviceDisplayGeometryMessage(
      displayWidth: Double(window.screen.nativeBounds.width),
      displayHeight: Double(window.screen.nativeBounds.height),
      viewWidth: Double(view.bounds.width * scale),
      viewHeight: Double(view.bounds.height * scale)
    )
  }
}
