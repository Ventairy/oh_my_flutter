part of '../motion.dart';

/// Adapts one effect lifecycle to the shared text timeline.
class _TextMotionEffect extends MotionEffect {
  new({
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

  static List<_TextMotionApplication> applicationsFor(List<_MotionApplication> applications) => [
    for (final application in applications)
      _applicationFor(application.animation, application.effect as _TextMotionEffect),
  ];

  static _TextMotionApplication _applicationFor(Animation<double> animation, _TextMotionEffect effect) => (
    animation: animation,
    effect: effect.effect,
    stagger: effect.stagger,
    timelineDuration: effect.duration,
  );

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
