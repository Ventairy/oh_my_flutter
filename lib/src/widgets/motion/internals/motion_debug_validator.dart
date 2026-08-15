part of '../motion.dart';

/// Checks configuration that Dart cannot assert in const constructors.
class _MotionDebugValidator {
  const _MotionDebugValidator._();

  static bool validateEffects(List<MotionEffect> effects) {
    assert(effects.isNotEmpty, 'effects must not be empty.');
    for (final effect in effects) {
      assert(effect.delay >= Duration.zero, 'delay must not be negative.');
      assert(effect.duration > Duration.zero, 'duration must be positive.');
      if (effect case MoveMotionEffect(:final begin, :final end)) {
        assert(begin.isFinite, 'begin must contain finite coordinates.');
        assert(end.isFinite, 'end must contain finite coordinates.');
      }
      if (effect case ShakeMotionEffect(:final offset)) {
        assert(offset.isFinite, 'offset must contain finite coordinates.');
      }
      final bounds = effect.bounds;
      if (bounds != null) {
        assert(
          bounds.minimumOffset.isFinite,
          'minimumOffset must contain finite coordinates.',
        );
        assert(
          bounds.maximumOffset.isFinite,
          'maximumOffset must contain finite coordinates.',
        );
        assert(
          bounds.minimumOffset.dx <= bounds.maximumOffset.dx && bounds.minimumOffset.dy <= bounds.maximumOffset.dy,
          'minimumOffset must not exceed maximumOffset.',
        );
      }
    }
    return true;
  }

  static bool validateTextInput(TextMotion textMotion) {
    assert(textMotion.stagger >= Duration.zero, 'stagger must not be negative.');
    assert(
      textMotion.child.data != null,
      'child must be created with Text.new; Text.rich is not supported.',
    );
    return validateEffects(
      textMotion.effect == null ? textMotion.effects! : <MotionEffect>[textMotion.effect!],
    );
  }
}
