import UIKit
import XCTest

@testable import oh_my_flutter

final class OhMyFlutterPluginTests: XCTestCase {
  private let deviceDisplayChannel =
    "dev.flutter.pigeon.oh_my_flutter.DeviceDisplayHostApi.getCornerRadii"

  func testWhenTheFlutterViewAttachesAfterRegistrationItShouldResolveItsView() {
    var viewController: UIViewController?
    let viewProvider = OhMyFlutterPlugin.makeFlutterViewProvider {
      viewController
    }
    viewController = UIViewController()
    viewController?.loadViewIfNeeded()

    let resolvedView = viewProvider()

    XCTAssertIdentical(resolvedView, viewController?.view)
  }

  func testWhenThePluginRegistersItShouldConnectTheDeviceDisplayHostApi() {
    let registrar = IOSFlutterPluginRegistrarSpy()

    OhMyFlutterPlugin.register(with: registrar)

    XCTAssertNotNil(registrar.binaryMessenger.messageHandlers[deviceDisplayChannel])
  }

  func testWhenThePluginDetachesItShouldDisconnectTheDeviceDisplayHostApi() {
    let registrar = IOSFlutterPluginRegistrarSpy()
    OhMyFlutterPlugin.register(with: registrar)
    let plugin = registrar.publishedValue as! OhMyFlutterPlugin

    plugin.detachFromEngine(for: registrar)

    XCTAssertNil(registrar.binaryMessenger.messageHandlers[deviceDisplayChannel])
  }
}
