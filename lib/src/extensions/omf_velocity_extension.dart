import 'package:flutter/gestures.dart';

/// Shared swipe helpers for Flutter [Velocity] values.
extension OmfVelocityExtension on Velocity {
  /// Whether this velocity represents a fast downward swipe.
  ///
  /// [minVelocity] is the minimum primary-axis speed in logical pixels per
  /// second. When [requireVerticalDominance] is `true`, the vertical speed
  /// must be strictly greater than the horizontal speed.
  bool isSwipeDown({double minVelocity = 700.0, bool requireVerticalDominance = true}) {
    return _isVerticalSwipe(
      minVelocity: minVelocity,
      requireVerticalDominance: requireVerticalDominance,
      isExpectedDirection: pixelsPerSecond.dy > 0,
    );
  }

  /// Whether this velocity represents a fast upward swipe.
  ///
  /// [minVelocity] is the minimum primary-axis speed in logical pixels per
  /// second. When [requireVerticalDominance] is `true`, the vertical speed
  /// must be strictly greater than the horizontal speed.
  bool isSwipeUp({double minVelocity = 700.0, bool requireVerticalDominance = true}) {
    return _isVerticalSwipe(
      minVelocity: minVelocity,
      requireVerticalDominance: requireVerticalDominance,
      isExpectedDirection: pixelsPerSecond.dy < 0,
    );
  }

  /// Whether this velocity represents a fast leftward swipe.
  ///
  /// [minVelocity] is the minimum primary-axis speed in logical pixels per
  /// second. When [requireHorizontalDominance] is `true`, the horizontal speed
  /// must be strictly greater than the vertical speed.
  bool isSwipeLeft({double minVelocity = 700.0, bool requireHorizontalDominance = true}) {
    return _isHorizontalSwipe(
      minVelocity: minVelocity,
      requireHorizontalDominance: requireHorizontalDominance,
      isExpectedDirection: pixelsPerSecond.dx < 0,
    );
  }

  /// Whether this velocity represents a fast rightward swipe.
  ///
  /// [minVelocity] is the minimum primary-axis speed in logical pixels per
  /// second. When [requireHorizontalDominance] is `true`, the horizontal speed
  /// must be strictly greater than the vertical speed.
  bool isSwipeRight({double minVelocity = 700.0, bool requireHorizontalDominance = true}) {
    return _isHorizontalSwipe(
      minVelocity: minVelocity,
      requireHorizontalDominance: requireHorizontalDominance,
      isExpectedDirection: pixelsPerSecond.dx > 0,
    );
  }

  bool _isVerticalSwipe({
    required double minVelocity,
    required bool requireVerticalDominance,
    required bool isExpectedDirection,
  }) {
    if (!isExpectedDirection) return false;

    final verticalVelocity = pixelsPerSecond.dy.abs();
    if (verticalVelocity < minVelocity) return false;

    final hasRequiredAxisDominance = !requireVerticalDominance || verticalVelocity > pixelsPerSecond.dx.abs();
    return hasRequiredAxisDominance;
  }

  bool _isHorizontalSwipe({
    required double minVelocity,
    required bool requireHorizontalDominance,
    required bool isExpectedDirection,
  }) {
    if (!isExpectedDirection) return false;

    final horizontalVelocity = pixelsPerSecond.dx.abs();
    if (horizontalVelocity < minVelocity) return false;

    final hasRequiredAxisDominance = !requireHorizontalDominance || horizontalVelocity > pixelsPerSecond.dy.abs();
    return hasRequiredAxisDominance;
  }
}
