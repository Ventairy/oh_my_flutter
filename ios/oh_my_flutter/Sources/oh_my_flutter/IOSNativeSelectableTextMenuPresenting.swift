import Flutter
import Foundation

/// Presents and dismisses one iOS selection-menu session.
internal protocol IOSNativeSelectableTextMenuPresenting: AnyObject {
  func show(request: NativeSelectableTextMenuRequestMessage) -> Bool

  func update(request: NativeSelectableTextMenuRequestMessage) -> Bool

  func updateGeometry(
    sessionIdentifier: Int64,
    geometry: FlutterStandardTypedData
  ) -> Bool

  func hide(sessionIdentifier: Int64)

  func dispose()
}
