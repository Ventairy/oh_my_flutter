import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'tag_status_route.dart';

class TagStatusScene {
  TagStatusScene({this.matched = true, this.reducedMotion = false});

  final bool matched;
  final bool reducedMotion;
  final observer = MorphNavigatorObserver();
  final navigator = GlobalKey<NavigatorState>();
  final source = MorphTarget(tag: 'surface');
  final route = TagStatusRoute();

  Widget get app => MaterialApp(
    debugShowCheckedModeBanner: false,
    navigatorKey: navigator,
    navigatorObservers: [observer],
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
      child: child!,
    ),
    home: ColoredBox(
      color: const Color(0xFFEEEEEE),
      child: Center(
        child: matched
            ? Morph(
                target: source,
                duration: const Duration(milliseconds: 300),
                child: const SizedBox.square(
                  dimension: 80,
                  child: ColoredBox(
                    color: Color(0xFF1565C0),
                    child: Center(
                      child: MorphDescendant(
                        flightBehavior: MorphDescendantFlightBehavior.snapshot,
                        child: SizedBox.square(dimension: 40, child: ColoredBox(color: Color(0xFFFFFFFF))),
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox(),
      ),
    ),
  );

  void push() => navigator.currentState!.push<void>(route);
}
