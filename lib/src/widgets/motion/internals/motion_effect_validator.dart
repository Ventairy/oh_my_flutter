part of '../motion.dart';

/// Validates effect configuration shared by both motion consumers.
class _MotionEffectValidator {
  const _MotionEffectValidator._();

  static void validateAll(List<MotionEffect> effects) {
    if (effects.isEmpty) {
      throw ArgumentError.value(effects, 'effects', 'must not be empty');
    }
    for (var index = 0; index < effects.length; index += 1) {
      _validate(effects[index], index);
    }
  }

  static void _validate(MotionEffect effect, int index) {
    if (effect.duration <= Duration.zero) {
      throw ArgumentError.value(
        effect.duration,
        'effects[$index].duration',
        'must be positive',
      );
    }
    if (effect.delay.isNegative) {
      throw ArgumentError.value(
        effect.delay,
        'effects[$index].delay',
        'must not be negative',
      );
    }
    if (effect is FloatingMotionEffect && (!effect.distance.isFinite || effect.distance <= 0)) {
      throw ArgumentError.value(
        effect.distance,
        'effects[$index].distance',
        'must be positive and finite',
      );
    }
    if (effect is ScaleInMotionEffect && !effect.scale.isFinite) {
      throw ArgumentError.value(
        effect.scale,
        'effects[$index].scale',
        'must be finite',
      );
    }
    if (effect is MoveMotionEffect && (!effect.begin.dx.isFinite || !effect.begin.dy.isFinite)) {
      throw ArgumentError.value(
        effect.begin,
        'effects[$index].begin',
        'must contain finite coordinates',
      );
    }
    if (effect is MoveMotionEffect && (!effect.end.dx.isFinite || !effect.end.dy.isFinite)) {
      throw ArgumentError.value(
        effect.end,
        'effects[$index].end',
        'must contain finite coordinates',
      );
    }
  }
}
