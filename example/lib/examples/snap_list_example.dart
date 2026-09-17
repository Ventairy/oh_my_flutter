// dart format width=80
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Demonstrates scroll-driven effects, both axes, and app-owned pagination.
class SnapListExample extends StatefulWidget {
  /// Creates an interactive snapping-list example.
  const SnapListExample({super.key});

  @override
  State<SnapListExample> createState() => _SnapListExampleState();
}

class _SnapListExampleState extends State<SnapListExample> {
  final _controller = SnapListController();
  Axis _axis = Axis.horizontal;
  var _count = 3;
  var _loading = false;
  var _failed = false;
  var _failNext = false;

  Future<void> _loadMore() async {
    if (_loading || _count >= 12) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (_failNext) {
        _failNext = false;
        _failed = true;
      } else {
        _count += 3;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: () => setState(
                () => _axis = _axis == Axis.horizontal
                    ? Axis.vertical
                    : Axis.horizontal,
              ),
              child: Text(
                _axis == Axis.horizontal ? 'Use vertical' : 'Use horizontal',
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _failNext = true),
              child: Text(_failNext ? 'Next load will fail' : 'Fail next load'),
            ),
          ],
        ),
        SizedBox(
          height: 260,
          child: SnapList.builder(
            controller: _controller,
            axis: _axis,
            itemCount: _count,
            spacing: 12,
            incomingTransitionBuilder: (context, progress, isReverse, child) =>
                FadeTransition(
                  opacity: isReverse
                      ? const AlwaysStoppedAnimation<double>(1)
                      : progress,
                  child: child,
                ),
            outgoingTransitionBuilder: (context, progress, isReverse, child) =>
                ScaleTransition(
                  scale: Tween<double>(begin: 1, end: .92).animate(progress),
                  child: child,
                ),
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeOutCubic,
            onIndexChanged: (index) {
              if (index >= _count - 2 && !_failed) unawaited(_loadMore());
            },
            trailingBuilder: (_) => SizedBox(
              width: _axis == Axis.horizontal ? 96 : null,
              height: _axis == Axis.vertical ? 96 : null,
              child: Center(
                child: _failed
                    ? TextButton(
                        onPressed: () => unawaited(_loadMore()),
                        child: const Text('Retry'),
                      )
                    : Text(
                        _count >= 12
                            ? 'All caught up'
                            : _loading
                            ? 'Loading…'
                            : 'More cards',
                      ),
              ),
            ),
            itemBuilder: (_, index) => DecoratedBox(
              key: ValueKey(index),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  'Card ${index + 1}',
                  style: TextStyle(color: colors.onSecondaryContainer),
                ),
              ),
            ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () => unawaited(_controller.previous()),
              child: const Text('Previous card'),
            ),
            ListenableBuilder(
              listenable: _controller,
              builder: (_, _) =>
                  Text('${(_controller.index ?? 0) + 1} / $_count'),
            ),
            TextButton(
              onPressed: () => unawaited(_controller.next()),
              child: const Text('Next card'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
