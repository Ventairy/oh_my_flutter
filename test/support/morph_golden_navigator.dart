import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Supplies the observer required by Morph golden scenarios.
class MorphGoldenNavigator extends StatefulWidget {
  /// Places [child] in an observed route while retaining the golden test theme.
  const new({required this.child, super.key});

  /// The golden scenario to display.
  final Widget child;

  @override
  State<MorphGoldenNavigator> createState() => _MorphGoldenNavigatorState();
}

class _MorphGoldenNavigatorState extends State<MorphGoldenNavigator> {
  final _observer = MorphNavigatorObserver();

  @override
  Widget build(BuildContext context) => Navigator(
    observers: [_observer],
    onDidRemovePage: (_) {},
    pages: [MaterialPage<void>(child: widget.child)],
  );
}
