part of 'motion.dart';

/// Collects the visual operations applied by [MotionEffect.apply].
///
/// Effects compose operations in declaration order. Effects must not retain an
/// instance after [MotionEffect.apply] returns.
final class MotionEffectTransform {
  MotionEffectTransform._();

  double _opacity = 1;
  double _scale = 1;
  double _translationX = 0;
  double _translationY = 0;

  /// Multiplies the current opacity by [opacity].
  void fade(double opacity) {
    _opacity *= opacity;
  }

  /// Applies a logical-pixel translation after earlier operations.
  void translate({required double x, required double y}) {
    _translationX += x;
    _translationY += y;
  }

  /// Applies a uniform scale after earlier operations.
  ///
  /// Earlier translations are scaled as well, matching nested Flutter
  /// transforms where later effects wrap earlier effects.
  void scale(double scale) {
    _translationX *= scale;
    _translationY *= scale;
    _scale *= scale;
  }

  void _reset() {
    _opacity = 1;
    _scale = 1;
    _translationX = 0;
    _translationY = 0;
  }
}
