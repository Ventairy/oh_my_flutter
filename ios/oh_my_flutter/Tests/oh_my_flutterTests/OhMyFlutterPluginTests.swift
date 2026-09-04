import UIKit
import XCTest

@testable import oh_my_flutter

final class OhMyFlutterPluginTests: XCTestCase {
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
}
