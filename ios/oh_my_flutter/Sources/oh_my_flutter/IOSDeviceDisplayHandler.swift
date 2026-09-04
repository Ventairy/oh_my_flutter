import UIKit

/// Reads public iOS display corner information for a full-screen Flutter view.
final class IOSDeviceDisplayHandler: DeviceDisplayHostApi {
  private let viewProvider: () -> UIView?
  private let supportsConcentricCorners: () -> Bool
  private let cornerRadiiReader: (UIWindow) -> DeviceDisplayCornerRadiiMessage?

  init(
    viewProvider: @escaping () -> UIView?,
    supportsConcentricCorners: @escaping () -> Bool = IOSDeviceDisplayHandler.defaultSupportsConcentricCorners,
    cornerRadiiReader: @escaping (UIWindow) -> DeviceDisplayCornerRadiiMessage? = IOSDeviceDisplayHandler.readCornerRadii
  ) {
    self.viewProvider = viewProvider
    self.supportsConcentricCorners = supportsConcentricCorners
    self.cornerRadiiReader = cornerRadiiReader
  }

  func getCornerRadii(
    geometry: DeviceDisplayGeometryMessage
  ) throws -> DeviceDisplayCornerRadiiMessage? {
    guard supportsConcentricCorners(), let view = viewProvider(), let window = view.window else {
      return nil
    }

    let screen = window.screen
    let scale = screen.scale
    guard scale.isFinite, scale > 0,
      matchesGeometry(
        geometry,
        displaySize: screen.nativeBounds.size,
        viewSize: view.bounds.size,
        scale: scale
      ),
      fillsWindow(view, window: window, scale: scale),
      fillsScreen(window, screen: screen, scale: scale)
    else {
      return nil
    }

    return cornerRadiiReader(window)
  }

  private func matchesGeometry(
    _ geometry: DeviceDisplayGeometryMessage,
    displaySize: CGSize,
    viewSize: CGSize,
    scale: CGFloat
  ) -> Bool {
    let values = [
      geometry.displayWidth,
      geometry.displayHeight,
      geometry.viewWidth,
      geometry.viewHeight,
    ]
    guard values.allSatisfy({ $0.isFinite && $0 > 0 }) else {
      return false
    }

    return approximatelyEqual(geometry.displayWidth, Double(displaySize.width))
      && approximatelyEqual(geometry.displayHeight, Double(displaySize.height))
      && approximatelyEqual(geometry.viewWidth, Double(viewSize.width * scale))
      && approximatelyEqual(geometry.viewHeight, Double(viewSize.height * scale))
  }

  private func fillsWindow(_ view: UIView, window: UIWindow, scale: CGFloat) -> Bool {
    let frame = view.convert(view.bounds, to: window)
    return approximatelyEqual(frame, window.bounds, tolerance: 1 / scale)
  }

  private func fillsScreen(_ window: UIWindow, screen: UIScreen, scale: CGFloat) -> Bool {
    let frame = screen.coordinateSpace.convert(window.bounds, from: window)
    return approximatelyEqual(frame, screen.coordinateSpace.bounds, tolerance: 1 / scale)
  }

  private func approximatelyEqual(_ expected: Double, _ actual: Double) -> Bool {
    return abs(expected - actual) <= 1
  }

  private func approximatelyEqual(_ expected: CGRect, _ actual: CGRect, tolerance: CGFloat) -> Bool {
    return abs(expected.minX - actual.minX) <= tolerance
      && abs(expected.minY - actual.minY) <= tolerance
      && abs(expected.width - actual.width) <= tolerance
      && abs(expected.height - actual.height) <= tolerance
  }

  private static func defaultSupportsConcentricCorners() -> Bool {
    if #available(iOS 26.0, *) {
      return true
    }
    return false
  }

  private static func readCornerRadii(_ window: UIWindow) -> DeviceDisplayCornerRadiiMessage? {
    guard #available(iOS 26.0, *) else {
      return nil
    }

    let probe = UIView(frame: window.bounds)
    probe.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    probe.backgroundColor = .clear
    probe.isOpaque = false
    probe.isUserInteractionEnabled = false
    probe.accessibilityElementsHidden = true
    probe.cornerConfiguration = .corners(radius: .containerConcentric())
    window.insertSubview(probe, at: 0)
    defer { probe.removeFromSuperview() }

    window.layoutIfNeeded()
    let scale = window.screen.scale
    return DeviceDisplayCornerRadiiMessage(
      topLeft: Double(probe.effectiveRadius(corner: .topLeft) * scale),
      topRight: Double(probe.effectiveRadius(corner: .topRight) * scale),
      bottomRight: Double(probe.effectiveRadius(corner: .bottomRight) * scale),
      bottomLeft: Double(probe.effectiveRadius(corner: .bottomLeft) * scale)
    )
  }
}
