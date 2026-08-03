import 'dart:async';

import 'package:flutter/widgets.dart';

/// Mutes ticker-driven animations in [child].
///
/// This widget controls frame callbacks through [TickerMode]. While callbacks
/// are muted, elapsed ticker time still advances, so animations catch up when
/// they resume.
class PauseAnimations extends StatefulWidget {
  /// Creates a widget that pauses child animation callbacks while [paused] is
  /// true.
  const PauseAnimations({
    required this.child,
    this.paused = true,
    super.key,
  }) : duration = Duration.zero,
       _temporary = false;

  /// Creates a widget that pauses child animation callbacks for [duration].
  ///
  /// The duration must not be negative. [Duration.zero] leaves callbacks
  /// enabled. Changing the duration restarts the temporary pause.
  const PauseAnimations.temporarily({
    required this.duration,
    required this.child,
    super.key,
  }) : paused = true,
       _temporary = true;

  /// Whether child animation callbacks are paused.
  ///
  /// This applies to the default constructor and defaults to true. Instances
  /// created with [PauseAnimations.temporarily] use [duration] instead.
  final bool paused;

  /// Length of the temporary pause.
  ///
  /// This is [Duration.zero] for instances created with the default
  /// constructor.
  final Duration duration;

  /// Widget whose ticker-driven animations are controlled.
  final Widget child;

  final bool _temporary;

  @override
  State<PauseAnimations> createState() => _PauseAnimationsState();
}

class _PauseAnimationsState extends State<PauseAnimations> {
  Timer? _timer;
  bool _temporarilyPaused = false;

  bool get _paused => widget._temporary ? _temporarilyPaused : widget.paused;

  @override
  void initState() {
    super.initState();
    _restartTemporaryPause();
  }

  @override
  void didUpdateWidget(covariant PauseAnimations oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._temporary != widget._temporary || oldWidget.duration != widget.duration) {
      _restartTemporaryPause();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restartTemporaryPause() {
    _timer?.cancel();
    _timer = null;
    if (!widget._temporary) {
      _temporarilyPaused = false;
      return;
    }
    final duration = widget.duration;
    if (duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'must not be negative');
    }
    _temporarilyPaused = duration > Duration.zero;
    if (!_temporarilyPaused) {
      return;
    }

    _timer = Timer(duration, () {
      _timer = null;
      if (!mounted || !_temporarilyPaused) {
        return;
      }
      setState(() => _temporarilyPaused = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: !_paused,
      child: widget.child,
    );
  }
}
