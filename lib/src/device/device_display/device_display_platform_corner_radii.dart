/// Describes display corner radii in current-orientation physical pixels.
final class DeviceDisplayPlatformCornerRadii {
  /// Creates physical-pixel radii for every display corner.
  const DeviceDisplayPlatformCornerRadii({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  /// The top-left corner radius in physical pixels.
  final double topLeft;

  /// The top-right corner radius in physical pixels.
  final double topRight;

  /// The bottom-right corner radius in physical pixels.
  final double bottomRight;

  /// The bottom-left corner radius in physical pixels.
  final double bottomLeft;
}
