part of 'motion.dart';

/// Collects the visual operations applied by [MotionEffect.apply].
///
/// Effects compose operations in declaration order. Effects must not retain an
/// instance after [MotionEffect.apply] returns.
final class MotionEffectTransform {
  new _();

  /// Default desired size of a disintegrating piece in logical source pixels.
  static const defaultParticleSize = 2.2;

  List<_MotionVisualOperation>? _operations;
  int _operationCount = 0;

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

  /// Breaks the current content into shrinking, fading pieces.
  ///
  /// [progress] is clamped to zero through one. [direction] is normalized;
  /// zero disables all movement. [particleSize] uses logical source pixels.
  /// Keep particle size and the number/order of disintegration calls constant
  /// throughout playback. Delay breakup by changing progress rather than
  /// conditionally calling this method. Later operations affect the pieces.
  void disintegrate({required double progress, required Offset direction, double particleSize = defaultParticleSize}) {
    assert(progress.isFinite, 'progress must be finite.');
    assert(direction.isFinite, 'direction must be finite.');
    assert(particleSize.isFinite && particleSize > 0, 'particleSize must be positive and finite.');
    _recordTransform();
    final operation = _nextOperation(.disintegrate);
    final largest = math.max(direction.dx.abs(), direction.dy.abs());
    final x = largest == 0 ? 0.0 : direction.dx / largest;
    final y = largest == 0 ? 0.0 : direction.dy / largest;
    final length = math.sqrt(x * x + y * y);
    operation
      ..progress = progress.clamp(0.0, 1.0)
      ..directionX = length == 0 ? 0 : x / length
      ..directionY = length == 0 ? 0 : y / length
      ..particleSize = particleSize;
    _resetTransform();
  }

  _MotionVisualOperation _nextOperation(_MotionVisualOperationKind kind) {
    final operations = _operations ??= [];
    if (_operationCount == operations.length) operations.add(_MotionVisualOperation(kind));
    final operation = operations[_operationCount++];
    assert(operation.kind == kind, 'Rendering operation order must remain constant.');
    return operation;
  }

  void _recordTransform() {
    _nextOperation(.transform)
      ..opacity = _opacity
      ..scale = _scale
      ..cosine = _cosine
      ..sine = _sine
      ..x = _translationX
      ..y = _translationY;
  }

  void _finishOperations() {
    if (_operationCount != 0) _recordTransform();
  }

  bool get _hasDisintegration => _operationCount != 0;

  static final _disintegrationEffects = Expando<bool>();

  static bool _usesDisintegration(List<MotionEffect> effects) {
    var found = false;
    for (final effect in effects) {
      var uses = kDebugMode ? null : _disintegrationEffects[effect];
      if (uses == null) {
        final transform = MotionEffectTransform._();
        effect.apply(effect.curve.transform(0), transform);
        uses = transform._hasDisintegration;
        assert(
          _validateOperationTopology(effect, transform._operationCount),
          'Rendering operation order must remain constant.',
        );
        _disintegrationEffects[effect] = uses;
      }
      found = found || uses;
    }
    return found;
  }

  static bool _validateOperationTopology(MotionEffect effect, int expected) {
    final transform = MotionEffectTransform._();
    final sizes = <double>[];
    for (var index = 0; index <= _MotionRenderEffect._boundsSampleCount; index++) {
      transform._reset();
      effect.apply(effect.curve.transform(index / _MotionRenderEffect._boundsSampleCount), transform);
      assert(transform._operationCount == expected, 'Disintegration calls must not depend on progress.');
      var stage = 0;
      for (var operation = 0; operation < transform._operationCount; operation++) {
        final value = transform._operations![operation];
        if (value.kind != .disintegrate) continue;
        if (index == 0) sizes.add(value.particleSize);
        assert(sizes[stage++] == value.particleSize, 'particleSize must remain constant throughout playback.');
      }
    }
    return true;
  }

  void _reset() {
    _operationCount = 0;
    _resetTransform();
  }

  void _resetTransform() {
    _opacity = 1;
    _scale = 1;
    _rotationDegrees = 0;
    _cosine = 1;
    _sine = 0;
    _translationX = 0;
    _translationY = 0;
  }
}
