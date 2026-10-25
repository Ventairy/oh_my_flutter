import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Compares a scheduled entrance with an entrance held until its contour is ready.
class ContourEntranceSample extends StatefulWidget {
  /// Creates one sticker with the selected entrance policy.
  const new({required this.child, required this.waitUntilReady, required this.delay, required this.pop, super.key});

  /// The same artwork used on both sides of the comparison.
  final Widget child;

  /// Whether preparation can finish before the full entrance begins.
  final bool waitUntilReady;

  /// The earliest time this sticker's entrance can begin.
  final Duration delay;

  /// Whether the entrance also scales, instead of only fading.
  final bool pop;

  @override
  State<ContourEntranceSample> createState() => _ContourEntranceSampleState();
}

class _ContourEntranceSampleState extends State<ContourEntranceSample> with SingleTickerProviderStateMixin {
  final _contour = ContourController();
  late final _entrance = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  late final _curve = CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic);
  late final Animation<double> _scale = Tween<double>(begin: .65, end: 1).animate(_curve);
  Timer? _deadline;
  bool _deadlineReached = false;
  bool _started = false;
  bool? _reducedMotion;

  @override
  void initState() {
    super.initState();
    _contour.addListener(_readinessChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion == reducedMotion) return;
    final firstBuild = _reducedMotion == null;
    _reducedMotion = reducedMotion;
    if (reducedMotion) {
      _deadline?.cancel();
      _deadlineReached = true;
      _started = true;
      _entrance.value = 1;
    } else if (firstBuild) {
      if (widget.delay == Duration.zero) {
        _deadlineReached = true;
        _startWhenEligible();
      } else {
        _deadline = Timer(widget.delay, () {
          _deadlineReached = true;
          _startWhenEligible();
        });
      }
    }
  }

  void _readinessChanged() {
    _startWhenEligible();
    setState(() {});
  }

  void _startWhenEligible() {
    if (_started || !_deadlineReached || (widget.waitUntilReady && !_contour.isReady)) return;
    _started = true;
    _entrance.forward();
  }

  @override
  void dispose() {
    _deadline?.cancel();
    _contour
      ..removeListener(_readinessChanged)
      ..dispose();
    _curve.dispose();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artwork = Contour(
      controller: _contour,
      prepareWhenHidden: widget.waitUntilReady,
      color: Colors.white,
      amount: 5,
      shadows: const [Shadow(color: Color(0x33000000), offset: Offset(0, 4), blurRadius: 8)],
      child: widget.child,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 84,
          child: Center(
            child: FadeTransition(
              opacity: _entrance,
              child: widget.pop ? ScaleTransition(scale: _scale, child: artwork) : artwork,
            ),
          ),
        ),
        Text(_contour.isReady ? 'Ready' : 'Preparing…', style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
