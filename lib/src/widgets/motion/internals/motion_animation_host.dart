part of '../motion.dart';

/// Owns the shared effect lifecycle without choosing a rendering strategy.
class _MotionAnimationHost extends StatefulWidget {
  const _MotionAnimationHost({
    required this.controller,
    required this.effects,
    required this.interactive,
    required this.transitionBuilder,
  });

  final MotionController? controller;

  final List<MotionEffect> effects;

  final bool interactive;

  final Widget Function(List<_MotionApplication> applications) transitionBuilder;

  @override
  State<_MotionAnimationHost> createState() => _MotionAnimationHostState();
}

class _MotionAnimationHostState extends State<_MotionAnimationHost> {
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
    _effects = List<MotionEffect>.of(widget.effects);
    _MotionEffectValidator.validateAll(_effects);
    _animationGroup = _MotionAnimationGroup();
    for (var index = 0; index < _effects.length; index += 1) {
      _addAnimation(_effects[index]);
    }
    widget.controller?._attach(_play);
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
  void didUpdateWidget(covariant _MotionAnimationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(_play);
      widget.controller?._attach(_play);
    }
    final previousEffects = _effects;
    final nextEffects = List<MotionEffect>.of(widget.effects);
    _MotionEffectValidator.validateAll(nextEffects);

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
    widget.controller?._detach(_play);
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

  void _play() {
    for (var index = 0; index < _effects.length; index += 1) {
      _delayTimers[index]?.cancel();
      _delayTimers[index] = null;
      _oneShotConsumed[index] = false;
      _playbackStarted[index] = false;
      _startCallbacksSent[index] = false;
      _effectCompleted[index] = false;
    }

    if (_animationsDisabled) {
      for (final animation in _animations) {
        animation.stopAt(0);
      }
      _applyReducedMotionEndpoint();
      return;
    }

    for (var index = 0; index < _effects.length; index += 1) {
      _schedulePlayback(index);
    }
    setState(() {});
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
    final applications = List<_MotionApplication>.generate(
      _effects.length,
      (index) => (
        animation: _animations[index],
        effect: _effects[index],
      ),
      growable: false,
    );
    final transition = widget.transitionBuilder(applications);
    if (!widget.interactive) {
      return IgnorePointer(
        ignoring: _hasIncompleteEffect,
        child: transition,
      );
    }
    return transition;
  }
}
