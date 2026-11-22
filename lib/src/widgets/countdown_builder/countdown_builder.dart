import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';

/// Builds UI with the time left before a deadline, such as a resend cooldown.
///
/// Widgets with the same deadline and update interval share update boundaries,
/// even if they mount at different times. The countdown catches up when the
/// app returns to the foreground.
///
/// See the [CountdownBuilder guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/countdown_builder.md).
class CountdownBuilder extends StatefulWidget {
  /// Creates a countdown that supplies the time remaining to [builder].
  const new({
    required this.endsAt,
    required this.updateInterval,
    required this.builder,
    this.onComplete,
    super.key,
  });

  /// The deadline at which the remaining duration becomes zero.
  final DateTime endsAt;

  /// The positive interval between updates measured backward from [endsAt].
  ///
  /// The first update can arrive sooner than this interval. The final update
  /// is scheduled for [endsAt] even when less than one interval remains.
  final Duration updateInterval;

  /// Builds the current UI with the remaining duration, clamped at zero.
  final Widget Function(BuildContext context, Duration remaining) builder;

  /// Runs once after zero is rendered for a deadline that was active while mounted.
  ///
  /// A deadline already reached when supplied does not invoke this callback.
  /// If an active deadline passes in the background, it completes on resume.
  final VoidCallback? onComplete;

  @override
  State<CountdownBuilder> createState() => _CountdownBuilderState();
}

class _CountdownBuilderState extends State<CountdownBuilder> with WidgetsBindingObserver {
  static bool _isValidUpdateInterval(Duration updateInterval) => updateInterval > Duration.zero;

  Timer? _updateTimer;
  Duration _remaining = Duration.zero;
  bool _awaitingCompletion = false;
  bool _completionPending = false;

  bool get _isForeground =>
      (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) == AppLifecycleState.resumed;

  void _readDeadline({bool isNewDeadline = false, bool fromTimer = false}) {
    assert(_isValidUpdateInterval(widget.updateInterval), 'updateInterval must be positive.');
    _updateTimer?.cancel();
    final remaining = widget.endsAt.difference(clock.now());
    final previousRemaining = _remaining;
    if (isNewDeadline) {
      _awaitingCompletion = remaining > Duration.zero;
      _completionPending = false;
    }
    _remaining = _awaitingCompletion && remaining > Duration.zero ? remaining : Duration.zero;
    if (!_isForeground) return;

    if (_remaining == Duration.zero) {
      if (!_awaitingCompletion) return;
      _awaitingCompletion = false;
      if (widget.onComplete == null) return;
      _completionPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_completionPending) return;
        _completionPending = false;
        widget.onComplete?.call();
      });
      return;
    }

    final remainingMicros = remaining.inMicroseconds;
    final intervalMicros = widget.updateInterval.inMicroseconds;
    // Sample just after the boundary. If the clock is unchanged, wait a full interval.
    final nextUpdateMicros = fromTimer && remaining == previousRemaining
        ? intervalMicros
        : remainingMicros % intervalMicros + 1;
    final delayMicros = remainingMicros <= intervalMicros ? remainingMicros : nextUpdateMicros;
    _updateTimer = Timer(Duration(microseconds: delayMicros), () {
      final previousRemaining = _remaining;
      _readDeadline(fromTimer: true);
      if (_remaining != previousRemaining) setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readDeadline(isNewDeadline: true);
  }

  @override
  void didUpdateWidget(covariant CountdownBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isNewDeadline = !widget.endsAt.isAtSameMomentAs(oldWidget.endsAt);
    if (isNewDeadline || widget.updateInterval != oldWidget.updateInterval) _readDeadline(isNewDeadline: isNewDeadline);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(_readDeadline);
      return;
    }
    _updateTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _remaining);
}
