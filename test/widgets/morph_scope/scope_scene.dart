import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

class ScopeScene {
  final ValueNotifier<bool> enabled = ValueNotifier(true);
  final observer = MorphNavigatorObserver();
  final navigator = GlobalKey<NavigatorState>();
  final source = MorphTarget(tag: 'scope', duration: const Duration(milliseconds: 400));

  bool sourceEnabled = true;
  bool destinationEnabled = true;
  int starts = 0;
  int ends = 0;

  Widget endpoint({required bool destination, required bool allowed}) => MorphScope(
    enabled: allowed,
    child: Morph(
      targets: [source],

      onStart: () => starts++,
      onEnd: () => ends++,
      child: SizedBox.square(
        dimension: destination ? 180 : 80,
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
    home: Center(child: endpoint(destination: false, allowed: sourceEnabled)),
  );

  void push() => navigator.currentState!.push<void>(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) =>
          Center(child: endpoint(destination: true, allowed: destinationEnabled)),
    ),
  );

  MorphTagStatus get status => source.status.value;
}
