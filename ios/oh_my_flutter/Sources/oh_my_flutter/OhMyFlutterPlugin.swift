import Flutter
import UIKit

/// Registers package-owned iOS capabilities with a Flutter engine.
public final class OhMyFlutterPlugin: NSObject, FlutterPlugin {
  private let binaryMessenger: FlutterBinaryMessenger
  private let deviceLocaleHandler = AppleDeviceLocaleHandler()
  private let deviceDisplayHandler: IOSDeviceDisplayHandler
  private let nativeSelectableTextMenuHandler: IOSNativeSelectableTextMenuHandler

  private init(
    binaryMessenger: FlutterBinaryMessenger,
    deviceDisplayHandler: IOSDeviceDisplayHandler,
    nativeSelectableTextMenuHandler: IOSNativeSelectableTextMenuHandler
  ) {
    self.binaryMessenger = binaryMessenger
    self.deviceDisplayHandler = deviceDisplayHandler
    self.nativeSelectableTextMenuHandler = nativeSelectableTextMenuHandler
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let binaryMessenger = registrar.messenger()
    let viewProvider = makeFlutterViewProvider { [weak registrar] in
      registrar?.viewController
    }
    let deviceDisplayHandler = IOSDeviceDisplayHandler(viewProvider: viewProvider)
    let flutterApi = NativeSelectableTextMenuFlutterApi(binaryMessenger: binaryMessenger)
    let handler = IOSNativeSelectableTextMenuHandler(
      viewProvider: viewProvider,
      flutterApi: flutterApi
    )
    let instance = OhMyFlutterPlugin(
      binaryMessenger: binaryMessenger,
      deviceDisplayHandler: deviceDisplayHandler,
      nativeSelectableTextMenuHandler: handler
    )
    DeviceDisplayHostApiSetup.setUp(
      binaryMessenger: binaryMessenger,
      api: deviceDisplayHandler
    )
    NativeSelectableTextMenuHostApiSetup.setUp(
      binaryMessenger: binaryMessenger,
      api: handler
    )
    DeviceLocaleHostApiSetup.setUp(binaryMessenger: binaryMessenger, api: instance.deviceLocaleHandler)
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
    DeviceLocaleHostApiSetup.setUp(binaryMessenger: binaryMessenger, api: nil)
    DeviceDisplayHostApiSetup.setUp(binaryMessenger: binaryMessenger, api: nil)
    NativeSelectableTextMenuHostApiSetup.setUp(binaryMessenger: binaryMessenger, api: nil)
    nativeSelectableTextMenuHandler.dispose()
  }

  deinit {
    nativeSelectableTextMenuHandler.dispose()
  }
}
