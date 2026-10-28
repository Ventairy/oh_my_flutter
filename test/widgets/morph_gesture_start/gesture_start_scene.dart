import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

part '_painted_elements.dart';

class GestureStartScene {
  new({
    this.material = false,
    this.matched = true,
    this.withHero = false,
    this.acceptMatch = true,
    this.destinationBounds = const Rect.fromLTWH(20, 30, 48, 48),
    this.duration,
    this.alternatives = false,
    this.nested = false,
    this.maintainDestination = true,
    this.reducedMotion = false,
  });

  final bool material;
  final bool matched;
  final bool withHero;
  final bool acceptMatch;
  final Rect destinationBounds;
  final Duration? duration;
  final bool alternatives;
  final bool nested;
  final bool maintainDestination;
  final bool reducedMotion;
  final GlobalKey frame = .new();
  final navigator = GlobalKey<NavigatorState>();
  final observer = MorphNavigatorObserver();
  final started = <String>[];
  final ended = <String>[];
  final parentTarget = MorphTarget(tag: #parent);
  final sourceAlternative = MorphTarget(tag: #sourceAlternative);
  final destinationAlternative = MorphTarget(tag: #destinationAlternative);
  late final target = MorphTarget(tag: #button, canMatch: (_) => acceptMatch, duration: duration);

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    push();
    await tester.pumpAndSettle();
    started.clear();
    ended.clear();
  }

  Widget get app => RepaintBoundary(
    key: frame,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(platform: .iOS),
      builder: reducedMotion
          ? (context, child) =>
                MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!)
          : null,
      home: HeroControllerScope.none(
        child: Navigator(
          key: navigator,
          observers: [observer, if (withHero) HeroController()],
          onGenerateRoute: (_) =>
              CupertinoPageRoute<void>(maintainState: maintainDestination, builder: (_) => page(incoming: false)),
        ),
      ),
    ),
  );

  Widget page({required bool incoming}) {
    final button = Morph(
      targets: [
        if (alternatives && incoming) destinationAlternative,
        if (alternatives && !incoming) sourceAlternative,
        if (incoming && !matched) destinationAlternative else target,
      ],
      onStart: () => started.add(incoming ? 'destination' : 'source'),
      onEnd: () => ended.add(incoming ? 'destination' : 'source'),
      child: const SizedBox.square(dimension: 48, child: ColoredBox(color: Color(0xFF00FF00))),
    );
    return ColoredBox(
      color: incoming ? const Color(0xFFF0F4FF) : Colors.white,
      child: Stack(
        children: [
          if (nested)
            Positioned(
              left: 0,
              top: 10,
              child: Morph(
                targets: [parentTarget],
                child: Container(
                  width: 220,
                  height: 120,
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.topLeft,
                  color: const Color(0xFFF0F0F0),
                  child: button,
                ),
              ),
            )
          else
            Positioned.fromRect(
              rect: incoming ? destinationBounds : const Rect.fromLTWH(20, 30, 48, 48),
              child: button,
            ),
          if (withHero)
            const Positioned(
              left: 200,
              top: 200,
              child: Hero(
                tag: #other,
                transitionOnUserGestures: true,
                child: SizedBox.square(dimension: 16, child: ColoredBox(color: Colors.blue)),
              ),
            ),
        ],
      ),
    );
  }

  void push() {
    final child = page(incoming: true);
    navigator.currentState!.push<void>(
      material ? MaterialPageRoute(builder: (_) => child) : CupertinoPageRoute(builder: (_) => child),
    );
  }

  Future<({Rect bounds, int pixels})> painted(WidgetTester tester) => _PaintedElements.green(tester, frame);
}
