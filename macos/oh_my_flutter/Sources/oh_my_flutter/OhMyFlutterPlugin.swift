import AppKit
import FlutterMacOS

/// Registers package-owned macOS capabilities with a Flutter engine.
public final class OhMyFlutterPlugin: NSObject, FlutterPlugin {
  private let nativeSelectableTextMenuHandler: MacOSNativeSelectableTextMenuHandler

  private init(nativeSelectableTextMenuHandler: MacOSNativeSelectableTextMenuHandler) {
    self.nativeSelectableTextMenuHandler = nativeSelectableTextMenuHandler
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let binaryMessenger = registrar.messenger
    let flutterApi = NativeSelectableTextMenuFlutterApi(binaryMessenger: binaryMessenger)
    let handler = MacOSNativeSelectableTextMenuHandler(
      viewProvider: { [weak view = registrar.view] in view },
      flutterApi: flutterApi
    )
    let instance = OhMyFlutterPlugin(nativeSelectableTextMenuHandler: handler)
    NativeSelectableTextMenuHostApiSetup.setUp(
      binaryMessenger: binaryMessenger,
      api: handler
    )
    registrar.publish(instance)
    registrar.addApplicationDelegate(instance)
  }

  public func handleWillTerminate(_: Notification) {
    nativeSelectableTextMenuHandler.dispose()
  }

  deinit {
    nativeSelectableTextMenuHandler.dispose()
  }
}
