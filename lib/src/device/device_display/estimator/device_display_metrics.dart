part of 'device_display_estimator.dart';

/// Describes the numeric display geometry available to a radius estimator.
///
/// Sizes, insets, and cutout bounds use Flutter logical pixels. [displaySize]
/// describes the complete display, while [viewSize] describes the current
/// Flutter view, which can be smaller in split-screen or windowed modes.
final class DeviceDisplayMetrics {
  /// Creates display metrics for an estimated corner-radius calculation.
  const DeviceDisplayMetrics({
    required this.platformKind,
    required this.displaySize,
    required this.viewSize,
    required this.devicePixelRatio,
    this.viewPadding = EdgeInsets.zero,
    this.systemGestureInsets = EdgeInsets.zero,
    this.displayCutoutBounds,
    this.displayCutoutCount = 0,
    this.hasFoldOrHinge = false,
  });

  /// The mobile platform whose display conventions should be considered.
  final DeviceDisplayPlatformKind platformKind;

  /// The complete display size in logical pixels.
  final Size displaySize;

  /// The current Flutter view size in logical pixels.
  final Size viewSize;

  /// The number of physical pixels represented by each logical pixel.
  final double devicePixelRatio;

  /// The unobscured padding around the current view in logical pixels.
  final EdgeInsets viewPadding;

  /// The system gesture-reserved insets in logical pixels.
  final EdgeInsets systemGestureInsets;

  /// The union of known display-cutout bounds in logical pixels, if any.
  final Rect? displayCutoutBounds;

  /// The number of known display cutouts represented by the aggregate bounds.
  final int displayCutoutCount;

  /// Whether the current display reports a fold or hinge feature.
  ///
  /// Foldable geometry is outside the estimator's phone-shaped training
  /// domain, so estimation is unavailable when this is `true`.
  final bool hasFoldOrHinge;
}
