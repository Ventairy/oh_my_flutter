import Flutter
import UIKit

/// Registers package-owned iOS capabilities with a Flutter engine.
public final class OhMyFlutterPlugin: NSObject, FlutterPlugin {
  private let binaryMessenger: FlutterBinaryMessenger
  private let nativeSelectableTextMenuHandler: IOSNativeSelectableTextMenuHandler

  private init(
    binaryMessenger: FlutterBinaryMessenger,
    nativeSelectableTextMenuHandler: IOSNativeSelectableTextMenuHandler
  ) {
    self.binaryMessenger = binaryMessenger
    self.nativeSelectableTextMenuHandler = nativeSelectableTextMenuHandler
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let binaryMessenger = registrar.messenger()
    let flutterApi = NativeSelectableTextMenuFlutterApi(binaryMessenger: binaryMessenger)
    let handler = IOSNativeSelectableTextMenuHandler(
      viewProvider: makeFlutterViewProvider { [weak registrar] in
        registrar?.viewController
      },
      flutterApi: flutterApi
    )
    let instance = OhMyFlutterPlugin(
      binaryMessenger: binaryMessenger,
      nativeSelectableTextMenuHandler: handler
    )
    NativeSelectableTextMenuHostApiSetup.setUp(
      binaryMessenger: binaryMessenger,
      api: handler
    )
    registrar.publish(instance)
  }

  internal static func makeFlutterViewProvider(
    viewControllerProvider: @escaping () -> UIViewController?
  ) -> () -> UIView? {
    {
      viewControllerProvider()?.viewIfLoaded
    }
  }

  public func detachFromEngine(for _: FlutterPluginRegistrar) {
    NativeSelectableTextMenuHostApiSetup.setUp(binaryMessenger: binaryMessenger, api: nil)
    nativeSelectableTextMenuHandler.dispose()
  }

  deinit {
    nativeSelectableTextMenuHandler.dispose()
  }
}
