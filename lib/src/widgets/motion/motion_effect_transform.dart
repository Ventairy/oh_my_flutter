part of 'motion.dart';

/// Collects the visual operations applied by [MotionEffect.apply].
///
/// Effects compose operations in declaration order. Effects must not retain an
/// instance after [MotionEffect.apply] returns.
final class MotionEffectTransform {
  new _();

  double _opacity = 1;
  double _scale = 1;
  double _rotationDegrees = 0;
  double _cosine = 1;
  double _sine = 0;
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

  /// Rotates around the child's center by [degrees] after earlier operations.
  ///
  /// Positive degrees rotate clockwise on screen. Earlier translations rotate
  /// with the child, matching the order of nested Flutter transforms.
  void rotate(double degrees) {
    final normalizedDegrees = degrees % 360;
    if (normalizedDegrees == 0) {
      _rotationDegrees += degrees;
      return;
    }
    final radians = normalizedDegrees * math.pi / 180;
    final cosine = math.cos(radians);
    final sine = math.sin(radians);
    final translationX = _translationX;
    _translationX = cosine * translationX - sine * _translationY;
    _translationY = sine * translationX + cosine * _translationY;
    final previousCosine = _cosine;
    _cosine = cosine * previousCosine - sine * _sine;
    _sine = sine * previousCosine + cosine * _sine;
    _rotationDegrees += degrees;
  }

  void _reset() {
    _opacity = 1;
    _scale = 1;
    _rotationDegrees = 0;
    _cosine = 1;
    _sine = 0;
    _translationX = 0;
    _translationY = 0;
  }
}
