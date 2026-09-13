import 'dart:ui' as ui;

import 'package:alchemist/alchemist.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

part 'morph_barrier_handoff/_barrier_handoff_scenario.dart';
part 'morph_barrier_handoff/_barrier_flight_delegate.dart';
part 'morph_barrier_handoff/_barrier_test_route.dart';
part 'morph_barrier_handoff/_barrier_snapshot_flight_delegate.dart';

Future<void> main() async {
  testWidgets('when snapshot content lands above a barrier, it should remain visible and release its captures', (
    tester,
  ) async {
    final scenario = _BarrierHandoffScenario(barrier: Colors.white54, captureContent: true);
    addTearDown(scenario.disabled.dispose);
    final images = <ui.Image>[];
    final previousOnCreate = ui.Image.onCreate;
    ui.Image.onCreate = (image) {
      images.add(image);
      previousOnCreate?.call(image);
    };
    addTearDown(() => ui.Image.onCreate = previousOnCreate);
    await tester.pumpWidget(scenario.app);
    await tester.pumpAndSettle();
    scenario.push();
    await tester.pumpAndSettle();
    scenario.navigator.currentState!.pop();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    final retained = images.any((image) => !image.debugDisposed);
    final heldPixel = await scenario.pixel(tester);
    await tester.pumpAndSettle();
    final landedPixel = await scenario.pixel(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(
      (retained, heldPixel, landedPixel, images.every((image) => image.debugDisposed), tester.takeException()),
      (true, Colors.blue.toARGB32(), Colors.blue.toARGB32(), true, null),
    );
  });

  for (final milliseconds in [0, 100, 230, 300, 600]) {
    for (final barrier in [null, Colors.transparent, Colors.white54]) {
      testWidgets('when route duration is $milliseconds with barrier $barrier, it should keep the independent timing', (
        tester,
      ) async {
        final scenario = _BarrierHandoffScenario(
          barrier: barrier,
          routeDuration: Duration(milliseconds: milliseconds),
        );
        addTearDown(scenario.disabled.dispose);
        await tester.pumpWidget(scenario.app);
        await tester.pumpAndSettle();
        scenario.push();
        await tester.pumpAndSettle();
        scenario.ended = 0;
        scenario.navigator.currentState!.pop();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 230));
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        if (milliseconds <= 230) await tester.pumpAndSettle();
        final held = scenario.flights.evaluate().isNotEmpty;
        expect(
          (held, scenario.ended, held ? tester.getSize(scenario.flights).width : 100.0),
          (barrier == Colors.white54 && milliseconds > 230, 1, 100.0),
        );
        await tester.pumpAndSettle();
      });
    }
  }

  testWidgets('when a push reverses before landing, it should hold above its departing barrier', (tester) async {
    final scenario = _BarrierHandoffScenario(
      barrier: Colors.white54,
      reverseDuration: const Duration(milliseconds: 900),
    );
    addTearDown(scenario.disabled.dispose);
    await tester.pumpWidget(scenario.app);
    await tester.pumpAndSettle();
    scenario.push();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    scenario.navigator.currentState!.pop();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    expect((scenario.flights.evaluate().length, await scenario.pixel(tester)), (1, Colors.blue.toARGB32()));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'when a gesture cancels after reaching a barrier hold, it should resume without waiting for route removal',
    (tester) async {
      final scenario = _BarrierHandoffScenario();
      addTearDown(scenario.disabled.dispose);
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      final route = _BarrierTestRoute(child: scenario.endpoint(MorphTarget(tag: scenario.source.tag)));
      scenario.navigator.currentState!.push(route);
      await tester.pumpAndSettle();
      scenario.navigator.currentState!.didStartUserGesture();
      route.previewReturn();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      final wasHeld = scenario.flights.evaluate().length == 1;
      route.cancelReturn();
      scenario.navigator.currentState!.didStopUserGesture();
      await tester.pumpAndSettle();
      expect(
        (wasHeld, scenario.flights.evaluate().length, route.isCurrent, tester.takeException()),
        (true, 0, true, null),
      );
    },
  );

  for (final action in ['retarget', 'remove route', 'disable motion', 'dispose navigator']) {
    testWidgets('when $action happens during a barrier hold, it should clean up without stale callbacks', (
      tester,
    ) async {
      final scenario = _BarrierHandoffScenario(barrier: Colors.white54);
      addTearDown(scenario.disabled.dispose);
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.push();
      await tester.pumpAndSettle();
      scenario.navigator.currentState!.pop();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 240));
      switch (action) {
        case 'retarget':
          scenario.push();
        case 'remove route':
          scenario.navigator.currentState!.removeRoute(scenario.route);
        case 'disable motion':
          scenario.disabled.value = true;
        case 'dispose navigator':
          await tester.pumpWidget(const SizedBox());
      }
      await tester.pumpAndSettle();
      expect((tester.takeException(), scenario.flights.evaluate().length), (null, 0));
    });
  }

  testWidgets('when a nested navigator pops a barrier route, it should hold in its own overlay', (tester) async {
    final scenario = _BarrierHandoffScenario(barrier: Colors.white54, nested: true);
    addTearDown(scenario.disabled.dispose);
    await tester.pumpWidget(scenario.app);
    await tester.pumpAndSettle();
    scenario.push();
    await tester.pumpAndSettle();
    scenario.navigator.currentState!.pop();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    expect((scenario.flights.evaluate().length, await scenario.pixel(tester)), (1, Colors.blue.toARGB32()));
    await tester.pumpAndSettle();
  });

  for (final barrier in [Colors.white, Colors.black]) {
    testWidgets(
      'when a ${barrier == Colors.white ? 'white' : 'black'} barrier outlasts the return, it should preserve the surface pixels through handoff',
      (tester) async {
        final scenario = _BarrierHandoffScenario(barrier: barrier.withValues(alpha: .5));
        addTearDown(scenario.disabled.dispose);
        await tester.pumpWidget(scenario.app);
        await tester.pumpAndSettle();
        scenario.push();
        await tester.pumpAndSettle();
        scenario.ended = 0;
        scenario.navigator.currentState!.pop();
        await tester.pump();
        await tester.pump();
        final pixels = <int>[];
        for (final elapsed in [229, 1, 1, 40, 29, 1]) {
          await tester.pump(Duration(milliseconds: elapsed));
          pixels.add(await scenario.pixel(tester));
        }
        await tester.pumpAndSettle();
        pixels.add(await scenario.pixel(tester));
        expect(
          [pixels.toSet(), scenario.ended, scenario.flights.evaluate().length],
          [
            {Colors.blue.toARGB32()},
            1,
            0,
          ],
        );
      },
    );
  }
  for (final elapsed in [240, 320]) {
    final scenarios = <_BarrierHandoffScenario>[];
    await goldenTest(
      'when a return reaches ${elapsed}ms, it should retain its color across the barrier handoff',
      fileName: 'morph_barrier_handoff_${elapsed}ms',
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        for (final scenario in scenarios) {
          scenario.push();
        }
        await tester.pumpAndSettle();
        for (final scenario in scenarios) {
          scenario.navigator.currentState!.pop();
        }
        await tester.pump();
        await tester.pump();
        await tester.pump(Duration(milliseconds: elapsed));
        if (elapsed > 300) await tester.pumpAndSettle();
      },
      builder: () {
        scenarios.clear();
        return GoldenTestGroup(
          columns: 2,
          children: [
            for (final barrier in [Colors.white54, Colors.black54])
              GoldenTestScenario(
                name: barrier == Colors.white54 ? 'White barrier' : 'Black barrier',
                child: Builder(
                  builder: (context) {
                    final scenario = _BarrierHandoffScenario(barrier: barrier);
                    scenarios.add(scenario);
                    return SizedBox(width: 260, height: 260, child: scenario.app);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
