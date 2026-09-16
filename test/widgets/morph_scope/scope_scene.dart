import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

class ScopeScene {
  final ValueNotifier<bool> enabled = ValueNotifier(true);
  final observer = MorphNavigatorObserver();
  final navigator = GlobalKey<NavigatorState>();
  final source = MorphTarget(tag: 'scope');
  final destination = MorphTarget(tag: 'scope');
  bool sourceEnabled = true;
  bool destinationEnabled = true;
  int starts = 0;
  int ends = 0;

  Widget endpoint(MorphTarget target, {required bool allowed}) => MorphScope(
    enabled: allowed,
    child: Morph(
      target: target,
      duration: const Duration(milliseconds: 400),
      onStart: () => starts++,
      onEnd: () => ends++,
      child: SizedBox.square(
        dimension: identical(target, source) ? 80 : 180,
        child: const ColoredBox(color: Colors.blue),
      ),
    ),
  );

  Widget get app => MaterialApp(
    debugShowCheckedModeBanner: false,
    navigatorKey: navigator,
    navigatorObservers: [observer],
    builder: (context, child) => ValueListenableBuilder<bool>(
      valueListenable: enabled,
      child: child,
      builder: (context, value, child) => MorphScope(enabled: value, child: child!),
    ),
    home: Center(child: endpoint(source, allowed: sourceEnabled)),
  );

  void push() => navigator.currentState!.push<void>(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) =>
          Center(child: endpoint(destination, allowed: destinationEnabled)),
    ),
  );

  MorphTagStatus get status => observer.tagStatus('scope').value;
}
