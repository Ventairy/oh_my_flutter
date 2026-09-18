import AppKit
import FlutterMacOS

/// Registers package-owned macOS capabilities with a Flutter engine.
public final class OhMyFlutterPlugin: NSObject, FlutterPlugin {
  private let deviceLocaleHandler = AppleDeviceLocaleHandler()
  private let binaryMessenger: FlutterBinaryMessenger
  private let nativeSelectableTextMenuHandler: MacOSNativeSelectableTextMenuHandler

  private init(
    binaryMessenger: FlutterBinaryMessenger,
    nativeSelectableTextMenuHandler: MacOSNativeSelectableTextMenuHandler
  ) {
    self.binaryMessenger = binaryMessenger
    self.nativeSelectableTextMenuHandler = nativeSelectableTextMenuHandler
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let binaryMessenger = registrar.messenger
    let flutterApi = NativeSelectableTextMenuFlutterApi(binaryMessenger: binaryMessenger)
    let handler = MacOSNativeSelectableTextMenuHandler(
      viewProvider: { [weak view = registrar.view] in view },
      flutterApi: flutterApi
    )
    let instance = OhMyFlutterPlugin(
      binaryMessenger: binaryMessenger, nativeSelectableTextMenuHandler: handler)
    NativeSelectableTextMenuHostApiSetup.setUp(
      binaryMessenger: binaryMessenger,
      api: handler
    )
    DeviceLocaleHostApiSetup.setUp(
      binaryMessenger: binaryMessenger, api: instance.deviceLocaleHandler)
    registrar.publish(instance)
    registrar.addApplicationDelegate(instance)
  }

  public func handleWillTerminate(_: Notification) {
    DeviceLocaleHostApiSetup.setUp(binaryMessenger: binaryMessenger, api: nil)
    nativeSelectableTextMenuHandler.dispose()
  }

  deinit {
    DeviceLocaleHostApiSetup.setUp(binaryMessenger: binaryMessenger, api: nil)
    nativeSelectableTextMenuHandler.dispose()
  }
}
