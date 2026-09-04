import Flutter

@testable import oh_my_flutter

internal final class IOSNativeSelectableTextMenuPresenterFake:
  IOSNativeSelectableTextMenuPresenting
{
  internal var showResult = true
  internal var updateResult = true
  internal var updateGeometryResult = true
  internal var shownRequest: NativeSelectableTextMenuRequestMessage?
  internal var updatedRequest: NativeSelectableTextMenuRequestMessage?
  internal var updatedGeometrySessionIdentifier: Int64?
  internal var updatedGeometry: FlutterStandardTypedData?
  internal var hiddenSessionIdentifier: Int64?
  internal var isDisposed = false

  internal func show(request: NativeSelectableTextMenuRequestMessage) -> Bool {
    shownRequest = request
    return showResult
  }

  internal func update(request: NativeSelectableTextMenuRequestMessage) -> Bool {
    updatedRequest = request
    return updateResult
  }

  internal func updateGeometry(
    sessionIdentifier: Int64,
    geometry: FlutterStandardTypedData
  ) -> Bool {
    updatedGeometrySessionIdentifier = sessionIdentifier
    updatedGeometry = geometry
    return updateGeometryResult
  }

  internal func hide(sessionIdentifier: Int64) {
    hiddenSessionIdentifier = sessionIdentifier
  }

  internal func dispose() {
    isDisposed = true
  }
}
