import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'morph_route_geometry/route_geometry_motion.dart';
import 'morph_route_geometry/route_geometry_scene.dart';

void main() {
  for (final withHero in [false, true]) {
    for (final motion in RouteGeometryMotion.values) {
      testWidgets(
        'when identical endpoints use $motion routes with Hero=$withHero, it should stay stationary through push and pop',
        (tester) async {
          final scene = RouteGeometryScene(motion: motion, withHero: withHero);
          addTearDown(scene.dispose);
          await tester.pumpWidget(scene.app);
          await tester.pumpAndSettle();
          scene.push();
          await tester.pump();
          await tester.pump();
          final samples = <Rect>[];
          for (final fraction in [0.1, 0.35, 0.4]) {
            await tester.pump(
              Duration(microseconds: (scene.pushedRoute!.transitionDuration.inMicroseconds * fraction).round()),
            );
            samples.add(tester.getRect(find.byKey(const ValueKey('flight_button'))));
          }
          await tester.pumpAndSettle();
          scene.navigator.currentState!.pop();
          await tester.pump();
          await tester.pump();
          for (final fraction in [0.1, 0.35, 0.4]) {
            await tester.pump(
              Duration(microseconds: (scene.pushedRoute!.reverseTransitionDuration.inMicroseconds * fraction).round()),
            );
            samples.add(tester.getRect(find.byKey(const ValueKey('flight_button'))));
          }
          await tester.pumpAndSettle();
          expect(samples, everyElement(const Rect.fromLTWH(20, 30, 48, 48)));
        },
      );
    }
  }

  for (final motion in [RouteGeometryMotion.horizontal, RouteGeometryMotion.vertical, RouteGeometryMotion.scale]) {
    testWidgets('when different endpoints use $motion, it should interpolate their settled bounds', (tester) async {
      final scene = RouteGeometryScene(motion: motion, destination: const Rect.fromLTWH(180, 200, 96, 80));
      addTearDown(scene.dispose);
      await tester.pumpWidget(scene.app);
      await tester.pumpAndSettle();
      scene.push();
      await tester.pump();
      await tester.pump();
      final samples = <bool>[];
      for (var frame = 0; frame < 3; frame++) {
        await tester.pump(const Duration(milliseconds: 80));
        final flight = scene.delegate.flight!;
        final expected = Rect.lerp(
          const Rect.fromLTWH(20, 30, 48, 48),
          const Rect.fromLTWH(180, 200, 96, 80),
          flight.curvedAnimation.value,
        )!;
        samples.add(
          (tester.getRect(find.byKey(const ValueKey('flight_button'))).topLeft - expected.topLeft).distance < 1e-8 &&
              flight.source.bounds == const Rect.fromLTWH(20, 30, 48, 48) &&
              flight.destination.bounds == const Rect.fromLTWH(180, 200, 96, 80),
        );
      }
      await tester.pumpAndSettle();
      expect(samples, everyElement(isTrue));
    });
  }

  testWidgets('when a Navigator is inset and scaled, it should preserve its placement throughout a route morph', (
    tester,
  ) async {
    final scene = RouteGeometryScene(nested: true);
    addTearDown(scene.dispose);
    await tester.pumpWidget(scene.app);
    await tester.pumpAndSettle();
    final source = tester.getRect(find.byKey(const ValueKey('source')));
    scene.push();
    await tester.pump();
    await tester.pump();
    final samples = <Rect>[];
    for (var frame = 0; frame < 3; frame++) {
      await tester.pump(const Duration(milliseconds: 80));
      samples.add(tester.getRect(find.byKey(const ValueKey('flight_button'))));
    }
    await tester.pumpAndSettle();
    expect(samples, everyElement(source));
  });

  testWidgets('when page content is scrolled and transformed, it should retain its local translation and scale', (
    tester,
  ) async {
    final scene = RouteGeometryScene(
      destination: const Rect.fromLTWH(20, 230, 48, 48),
      scrollOffset: 100,
      contentTransform: Matrix4.identity()
        ..translateByDouble(12, 8, 0, 1)
        ..scaleByDouble(1.25, 1.25, 1, 1),
    );
    addTearDown(scene.dispose);
    await tester.pumpWidget(scene.app);
    await tester.pumpAndSettle();
    scene.push();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final flight = scene.delegate.flight!;
    expect(
      (flight.source.bounds, flight.destination.bounds, flight.destination.axisScale),
      (const Rect.fromLTWH(32, -62, 60, 60), const Rect.fromLTWH(32, 138, 60, 60), const Offset(1.25, 1.25)),
    );
    await tester.pumpAndSettle();
  });

  testWidgets(
    'when a watched destination moves inside an arriving page, it should follow content movement without following the route',
    (tester) async {
      final scene = RouteGeometryScene(watchDestination: true);
      addTearDown(scene.dispose);
      await tester.pumpWidget(scene.app);
      await tester.pumpAndSettle();
      scene.push();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final initial = scene.delegate.flight!.destination.bounds;
      scene.destinationOffset.value = const Offset(40, 15);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        (initial, scene.delegate.flight!.destination.bounds),
        (const Rect.fromLTWH(20, 30, 48, 48), const Rect.fromLTWH(60, 45, 48, 48)),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets('when a push reverses midflight, it should keep identical endpoints stationary', (tester) async {
    final scene = RouteGeometryScene();
    addTearDown(scene.dispose);
    await tester.pumpWidget(scene.app);
    await tester.pumpAndSettle();
    scene.push();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    final before = tester.getRect(find.byKey(const ValueKey('flight_button')));
    scene.navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final after = tester.getRect(find.byKey(const ValueKey('flight_button')));
    await tester.pumpAndSettle();
    expect(
      (before, after, scene.target.status.value),
      (const Rect.fromLTWH(20, 30, 48, 48), const Rect.fromLTWH(20, 30, 48, 48), MorphTagStatus.completed),
    );
  });

  for (final commit in [false, true]) {
    testWidgets('when interactive Back commits=$commit, it should keep the flight stationary and hand off correctly', (
      tester,
    ) async {
      final scene = RouteGeometryScene(motion: .cupertino);
      addTearDown(scene.dispose);
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(scene.app);
      await tester.pumpAndSettle();
      scene.push();
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(const Offset(1, 350));
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      await gesture.moveBy(Offset(commit ? 300 : 80, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final bounds = tester.getRect(find.byKey(const ValueKey('flight_button')));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(
        (bounds, scene.target.status.value),
        (const Rect.fromLTWH(20, 30, 48, 48), commit ? MorphTagStatus.completed : MorphTagStatus.cancelled),
      );
    });
  }

  testWidgets(
    'when a surface and nested header expand on an untransformed route, it should preserve both trajectories and return handoff',
    (tester) async {
      final scene = NestedGeometryScene();
      await tester.pumpWidget(scene.app);
      await tester.pumpAndSettle();
      scene.push();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      final surface = scene.surfaceDelegate.flight!;
      final header = scene.headerDelegate.flight!;
      final endpoints = [
        surface.source.bounds,
        surface.destination.bounds,
        header.source.bounds,
        header.destination.bounds,
      ];
      await tester.pumpAndSettle();
      scene.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(
        {'endpoints': endpoints, 'surface': scene.surface.status.value, 'header': scene.header.status.value},
        {
          'endpoints': [
            const Rect.fromLTWH(30, 120, 240, 180),
            const Rect.fromLTWH(0, 0, 400, 600),
            const Rect.fromLTWH(50, 140, 140, 40),
            const Rect.fromLTWH(40, 40, 200, 60),
          ],
          'surface': MorphTagStatus.completed,
          'header': MorphTagStatus.completed,
        },
      );
    },
  );

  testWidgets('when a non-page modal supplies its own transform, it should preserve its existing overlay geometry', (
    tester,
  ) async {
    final scene = RouteGeometryScene();
    addTearDown(scene.dispose);
    await tester.pumpWidget(scene.app);
    await tester.pumpAndSettle();
    scene.navigator.currentState!.push<void>(
      RawDialogRoute(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, _, _) => Transform.translate(
          offset: const Offset(70, 20),
          child: scene.page(const Rect.fromLTWH(20, 30, 48, 48), incoming: true),
        ),
        transitionBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(scene.delegate.flight!.destination.bounds, const Rect.fromLTWH(90, 50, 48, 48));
    await tester.pumpAndSettle();
  });

  testWidgets('when another push interrupts a route flight, it should start from the current visible geometry', (
    tester,
  ) async {
    final scene = RouteGeometryScene(destination: const Rect.fromLTWH(180, 200, 96, 80));
    addTearDown(scene.dispose);
    await tester.pumpWidget(scene.app);
    await tester.pumpAndSettle();
    scene.push();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    final before = scene.delegate.flight!.bounds;
    scene.push();
    await tester.pump();
    await tester.pump();
    final after = scene.delegate.flight!.source.bounds;
    await tester.pumpAndSettle();
    expect(after, before);
  });

  testWidgets('when an appearance changes within a translated route, it should keep same-page live coordinates', (
    tester,
  ) async {
    final scene = RouteGeometryScene();
    addTearDown(scene.dispose);
    final bounds = ValueNotifier(const Rect.fromLTWH(20, 30, 48, 48));
    addTearDown(bounds.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          observers: [scene.observer],
          onGenerateRoute: (_) => PageRouteBuilder<void>(
            transitionsBuilder: (_, _, _, child) => Transform.translate(offset: const Offset(50, 10), child: child),
            pageBuilder: (_, _, _) => ValueListenableBuilder(
              valueListenable: bounds,
              builder: (_, rect, _) => Stack(
                children: [
                  Positioned.fromRect(
                    rect: rect,
                    child: Morph(
                      key: ValueKey(rect),
                      targets: [scene.target],
                      flightConfig: .custom(scene.delegate),
                      child: const ColoredBox(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    bounds.value = const Rect.fromLTWH(100, 130, 48, 48);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final flight = scene.delegate.flight!;
    expect(
      (flight.kind, flight.source.bounds, flight.destination.bounds),
      (MorphFlightKind.sameScreen, const Rect.fromLTWH(70, 40, 48, 48), const Rect.fromLTWH(150, 140, 48, 48)),
    );
    await tester.pumpAndSettle();
  });
}
