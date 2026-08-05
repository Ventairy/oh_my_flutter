part of '../motion.dart';

/// Adapts one effect lifecycle to the shared text timeline.
class _TextMotionEffect extends MotionEffect {
  _TextMotionEffect({
    required this.effect,
    required this.stagger,
    required int characterCount,
  }) : super(
         delay: effect.delay,
         duration: _timelineDuration(
           effect: effect,
           stagger: stagger,
           characterCount: characterCount,
         ),
         curve: Curves.linear,
         playback: effect.playback,
         onStart: effect.onStart,
         onEnd: effect.onEnd,
       );

  final MotionEffect effect;

  final Duration stagger;

  static Duration _timelineDuration({
    required MotionEffect effect,
    required Duration stagger,
    required int characterCount,
  }) {
    if (!effect.playback.isOnce || characterCount < 2) {
      return effect.duration;
    }
    return effect.duration +
        Duration(
          microseconds: stagger.inMicroseconds * (characterCount - 1),
        );
  }

  @override
  void apply(double progress, MotionEffectTransform transform) {
    effect.apply(progress, transform);
  }
}
