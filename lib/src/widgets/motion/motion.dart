import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

part 'effects/fade_in_motion_effect.dart';
part 'effects/floating_motion_effect.dart';
part 'effects/move_motion_effect.dart';
part 'effects/scale_in_motion_effect.dart';
part 'internals/animated_motion_scale.dart';
part 'internals/animated_motion_translation.dart';
part 'internals/motion_animation.dart';
part 'internals/motion_animation_group.dart';
part 'internals/motion_scheduler.dart';
part 'internals/render_animated_motion_scale.dart';
part 'internals/render_animated_motion_translation.dart';
part 'motion_effect.dart';
part 'motion_playback.dart';

/// Applies one or more reusable [MotionEffect]s to [child].
///
/// [Motion] owns the animation lifecycle so effects only need to compose a
/// visual transition around the supplied child. Use [Motion.list] to run
/// multiple effects from one lifecycle and scheduler entry. Active instances
/// share one frame callback, regardless of how many motions are mounted.
/// Motion also respects reduced-motion preferences and [TickerMode].
///
/// ```dart
/// Motion(
///   effect: const FloatingMotionEffect(
///     delay: Duration(milliseconds: 300),
///   ),
///   child: const Icon(Icons.cloud),
/// )
/// ```
class Motion extends StatefulWidget {
  /// Creates a widget that applies one [effect] to [child].
  const Motion({
    required this.effect,
    required this.child,
    this.interactive = false,
    super.key,
  }) : effects = null;

  /// Creates a widget that applies [effects] concurrently to [child].
  ///
  /// Each effect has independent delay, duration, curve, and playback values.
  /// The first effect is placed closest to [child], and each following effect
  /// wraps the result. The list must contain at least one effect and must not
  /// be mutated after being passed to this constructor.
  const Motion.list({
    required this.effects,
    required this.child,
    this.interactive = false,
    super.key,
  }) : effect = null;

  /// Single effect supplied to the default constructor.
  ///
  /// This is null when the widget was created with [Motion.list].
  final MotionEffect? effect;

  /// Effects supplied to the multi-effect constructor.
  ///
  /// This is null when the widget was created with the default constructor.
  final List<MotionEffect>? effects;

  /// Whether [child] accepts pointer interaction during the effect lifecycle.
  ///
  /// This defaults to false, so all pointer interaction is ignored while at
  /// least one effect is waiting or playing. Set this to true to keep the child
  /// interactive throughout the motion lifecycle. Interaction becomes enabled
  /// after every one-shot effect completes. Looping effects keep interaction
  /// disabled for as long as they remain mounted when this is false.
  final bool interactive;

  /// Widget receiving the motion treatment.
  final Widget child;

  @override
  State<Motion> createState() => _MotionState();
}

class _MotionState extends State<Motion> {
  late final _MotionAnimationGroup _animationGroup;
  late List<MotionEffect> _effects;
  final List<_MotionAnimation> _animations = <_MotionAnimation>[];
  final List<AnimationStatusListener> _statusListeners = <AnimationStatusListener>[];
  final List<Timer?> _delayTimers = <Timer?>[];
  final List<bool> _oneShotConsumed = <bool>[];
  final List<bool> _playbackStarted = <bool>[];
  final List<bool> _startCallbacksSent = <bool>[];
  final List<bool> _effectCompleted = <bool>[];
  bool _animationsDisabled = false;
  bool _tickersEnabled = true;
  bool _forceFrames = false;
  bool _dependenciesReady = false;

  @override
  void initState() {
    super.initState();
    _effects = _readEffects();
    _validateEffects(_effects);
    _animationGroup = _MotionAnimationGroup();
    for (var index = 0; index < _effects.length; index += 1) {
      _addAnimation(_effects[index]);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animationsDisabled = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final tickerMode = TickerMode.valuesOf(context);
    final tickersEnabled = tickerMode.enabled;
    final forceFrames = tickerMode.forceFrames;
    final accessibilityChanged = !_dependenciesReady || animationsDisabled != _animationsDisabled;
    final tickerModeChanged = !_dependenciesReady || tickersEnabled != _tickersEnabled;
    final forceFramesChanged = !_dependenciesReady || forceFrames != _forceFrames;
    if (!accessibilityChanged && !tickerModeChanged && !forceFramesChanged) {
      return;
    }

    _dependenciesReady = true;
    _animationsDisabled = animationsDisabled;
    _tickersEnabled = tickersEnabled;
    _forceFrames = forceFrames;
    _animationGroup.muted = !_tickersEnabled;
    _animationGroup.forceFrames = _forceFrames;
    if (tickerModeChanged && _tickersEnabled) {
      _sendPendingStartCallbacks();
    }
    if (!accessibilityChanged) {
      return;
    }
    if (_animationsDisabled) {
      _applyReducedMotionEndpoint();
      return;
    }

    _resumeAfterReducedMotion();
  }

  @override
  void didUpdateWidget(covariant Motion oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousEffects = _effects;
    final nextEffects = _readEffects();
    _validateEffects(nextEffects);

    while (_animations.length > nextEffects.length) {
      _removeLastAnimation();
    }
    while (_animations.length < nextEffects.length) {
      _addAnimation(nextEffects[_animations.length]);
    }
    _effects = nextEffects;

    for (var index = 0; index < nextEffects.length; index += 1) {
      if (index >= previousEffects.length) {
        if (_animationsDisabled) {
          _applyReducedMotionEndpoint(index);
        } else {
          _schedulePlayback(index);
        }
        continue;
      }

      final oldEffect = previousEffects[index];
      final effect = nextEffects[index];
      final animation = _animations[index];
      if (oldEffect.duration != effect.duration) {
        animation.duration = effect.duration;
      }
      if (oldEffect.curve != effect.curve) {
        animation.curve = effect.curve;
      }
      if (oldEffect.playback != effect.playback) {
        animation.playback = effect.playback;
        _oneShotConsumed[index] = false;
        _playbackStarted[index] = false;
        _startCallbacksSent[index] = false;
        _effectCompleted[index] = false;
        if (_animationsDisabled) {
          _applyReducedMotionEndpoint(index);
        } else {
          _schedulePlayback(index);
        }
        continue;
      }
      if (oldEffect.delay != effect.delay && _delayTimers[index] != null) {
        _schedulePlayback(index);
      }
    }
  }

  @override
  void dispose() {
    for (var index = 0; index < _delayTimers.length; index += 1) {
      _delayTimers[index]?.cancel();
      _animations[index].removeStatusListener(
        _statusListeners[index],
      );
      _animations[index].dispose();
    }
    _animationGroup.dispose();
    super.dispose();
  }

  List<MotionEffect> _readEffects() {
    final effect = widget.effect;
    if (effect != null) {
      return <MotionEffect>[effect];
    }
    return List<MotionEffect>.of(widget.effects!);
  }

  void _addAnimation(MotionEffect effect) {
    final index = _animations.length;
    final animation = _MotionAnimation(
      _animationGroup,
      effect.duration,
      effect.curve,
      effect.playback,
    );
    void handleStatusChanged(AnimationStatus status) {
      _handleAnimationStatusChanged(index, status);
    }

    _animationGroup.add(animation);
    animation.addStatusListener(handleStatusChanged);
    _animations.add(animation);
    _statusListeners.add(handleStatusChanged);
    _delayTimers.add(null);
    _oneShotConsumed.add(false);
    _playbackStarted.add(false);
    _startCallbacksSent.add(false);
    _effectCompleted.add(false);
  }

  void _removeLastAnimation() {
    _delayTimers.removeLast()?.cancel();
    _oneShotConsumed.removeLast();
    _playbackStarted.removeLast();
    _startCallbacksSent.removeLast();
    _effectCompleted.removeLast();
    final statusListener = _statusListeners.removeLast();
    final animation = _animations.removeLast()
      ..removeStatusListener(statusListener)
      ..dispose();
    _animationGroup.remove(animation);
  }

  void _schedulePlayback(int index) {
    _delayTimers[index]?.cancel();
    _delayTimers[index] = null;
    _startCallbacksSent[index] = false;
    _effectCompleted[index] = false;
    _animations[index].stopAt(0);
    final delay = _effects[index].delay;

    if (delay == Duration.zero) {
      _startPlayback(index);
      return;
    }

    _delayTimers[index] = Timer(delay, () {
      _delayTimers[index] = null;
      if (!mounted || _animationsDisabled) {
        return;
      }
      _startPlayback(index);
    });
  }

  void _startPlayback(int index) {
    _delayTimers[index]?.cancel();
    _delayTimers[index] = null;
    _playbackStarted[index] = true;
    _animations[index].start();
    _sendStartCallback(index);

    if (_effects[index].playback.isOnce) {
      _oneShotConsumed[index] = true;
    }
  }

  void _applyReducedMotionEndpoint([int? effectIndex]) {
    final firstIndex = effectIndex ?? 0;
    final endIndex = effectIndex == null ? _effects.length : effectIndex + 1;
    for (var index = firstIndex; index < endIndex; index += 1) {
      _delayTimers[index]?.cancel();
      _delayTimers[index] = null;
      final playback = _effects[index].playback;
      if (playback.isOnce) {
        if (!_oneShotConsumed[index]) {
          _playbackStarted[index] = true;
          _startCallbacksSent[index] = true;
          _dispatchEffectCallback(index, _effects[index].onStart);
        }
        _oneShotConsumed[index] = true;
      }
      _animations[index].stopAt(
        switch (playback) {
          MotionPlayback.once => 1,
          MotionPlayback.loop => 0,
        },
      );
    }
  }

  void _resumeAfterReducedMotion() {
    for (var index = 0; index < _effects.length; index += 1) {
      if (_effects[index].playback.isOnce && _oneShotConsumed[index]) {
        continue;
      }
      if (_playbackStarted[index]) {
        _startPlayback(index);
      } else {
        _schedulePlayback(index);
      }
    }
  }

  void _validateEffects(List<MotionEffect> effects) {
    if (effects.isEmpty) {
      throw ArgumentError.value(effects, 'effects', 'must not be empty');
    }
    for (var index = 0; index < effects.length; index += 1) {
      final effect = effects[index];
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

  void _handleAnimationStatusChanged(int index, AnimationStatus status) {
    if (status.isCompleted && _effects[index].playback.isOnce && !_effectCompleted[index]) {
      _effectCompleted[index] = true;
      _dispatchEffectCallback(index, _effects[index].onEnd);
      setState(() {});
    }
  }

  void _sendPendingStartCallbacks() {
    for (var index = 0; index < _animations.length; index += 1) {
      if (_animations[index]._isRunning) {
        _sendStartCallback(index);
      }
    }
  }

  void _sendStartCallback(int index) {
    if (_startCallbacksSent[index] || !_tickersEnabled) {
      return;
    }
    _startCallbacksSent[index] = true;
    _dispatchEffectCallback(index, _effects[index].onStart);
  }

  void _dispatchEffectCallback(int index, VoidCallback? callback) {
    if (callback == null) {
      return;
    }
    final animation = _animations[index];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _animations.length || !identical(_animations[index], animation)) {
        return;
      }
      callback();
    });
  }

  bool get _hasIncompleteEffect {
    for (var index = 0; index < _effectCompleted.length; index += 1) {
      if (!_effectCompleted[index]) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    var transition = widget.child;
    for (var index = 0; index < _effects.length; index += 1) {
      transition = _effects[index].buildTransition(
        context,
        _animations[index],
        transition,
      );
    }
    if (!widget.interactive) {
      return IgnorePointer(
        ignoring: _hasIncompleteEffect,
        child: transition,
      );
    }
    return transition;
  }
}
