import Flutter
import UIKit

/// Routes Pigeon requests to the system edit-menu implementation when available.
internal final class IOSNativeSelectableTextMenuHandler: NativeSelectableTextMenuHostApi {
  private let presenter: IOSNativeSelectableTextMenuPresenting?

  internal init(
    viewProvider: @escaping () -> UIView?,
    flutterApi: NativeSelectableTextMenuFlutterApiProtocol
  ) {
    if #available(iOS 16.0, *) {
      presenter = IOSNativeSelectableTextMenuPresenter(
        viewProvider: viewProvider,
        flutterApi: flutterApi
      )
    } else {
      presenter = nil
    }
  }

  internal init(presenter: IOSNativeSelectableTextMenuPresenting?) {
    self.presenter = presenter
  }

  internal func show(request: NativeSelectableTextMenuRequestMessage) -> Bool {
    presenter?.show(request: request) ?? false
  }

  internal func update(request: NativeSelectableTextMenuRequestMessage) -> Bool {
    presenter?.update(request: request) ?? false
  }

  internal func updateGeometry(
    sessionIdentifier: Int64,
    geometry: FlutterStandardTypedData
  ) -> Bool {
    presenter?.updateGeometry(
      sessionIdentifier: sessionIdentifier,
      geometry: geometry
    ) ?? false
  }

  internal func hide(sessionIdentifier: Int64) {
    presenter?.hide(sessionIdentifier: sessionIdentifier)
  }

  internal func dispose() {
    presenter?.dispose()
  }
}
