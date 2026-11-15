part of '../../motion.dart';

abstract final class _MotionDisintegrationTable {
  static const sampleCount = 4096;
  static const stride = 4;
  static final Float32List samples = _createSamples();

  static Float32List _createSamples() {
    final values = Float32List((sampleCount + 1) * stride);
    for (var index = 0; index <= sampleCount; index++) {
      final life = index / sampleCount;
      final unbroken = 1 - (life * _MotionDisintegrationParameters.breakupRate).clamp(0.0, 1.0);
      final breakup = 1 - unbroken * unbroken * unbroken;
      final fade =
          ((life - _MotionDisintegrationParameters.fadeStart) / (1 - _MotionDisintegrationParameters.fadeStart)).clamp(
            0.0,
            1.0,
          );
      final offset = index * stride;
      // Scale, alpha, and the shared sine/cosine terms of the particle curl.
      values[offset] =
          (1 - _MotionDisintegrationParameters.breakupShrink * breakup) *
          (1 - _MotionDisintegrationParameters.lifetimeShrink * life);
      values[offset + 1] = (1 - fade * fade * (3 - 2 * fade)) * 255;
      values[offset + 2] = math.sin(life * _MotionDisintegrationParameters.curlRotation) * math.sin(life * math.pi);
      values[offset + 3] = math.cos(life * _MotionDisintegrationParameters.curlRotation) * math.sin(life * math.pi);
    }
    return values.asUnmodifiableView();
  }
}
