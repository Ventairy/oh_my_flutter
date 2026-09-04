import Flutter
import UIKit

/// Records plugin registration state for iOS tests.
internal final class IOSFlutterPluginRegistrarSpy: NSObject, FlutterPluginRegistrar {
  internal let binaryMessenger = IOSNativeSelectableTextMenuBinaryMessengerSpy()
  internal private(set) var publishedValue: NSObject?
  internal var viewController: UIViewController?

  internal func messenger() -> FlutterBinaryMessenger {
    binaryMessenger
  }

  internal func textures() -> FlutterTextureRegistry {
    fatalError("Textures are not used by these tests.")
  }

  internal func register(_: FlutterPlatformViewFactory, withId _: String) {}

  internal func register(
    _: FlutterPlatformViewFactory,
    withId _: String,
    gestureRecognizersBlockingPolicy _: FlutterPlatformViewGestureRecognizersBlockingPolicy
  ) {}

  internal func publish(_ value: NSObject) {
    publishedValue = value
  }

  internal func addMethodCallDelegate(_: FlutterPlugin, channel _: FlutterMethodChannel) {}

  internal func addApplicationDelegate(_: FlutterPlugin) {}

  internal func addSceneDelegate(_: FlutterSceneLifeCycleDelegate) {}

  internal func lookupKey(forAsset _: String) -> String {
    ""
  }

  internal func lookupKey(forAsset _: String, fromPackage _: String) -> String {
    ""
  }

  internal func valuePublished(byPlugin _: String) -> NSObject? {
    nil
  }
}
