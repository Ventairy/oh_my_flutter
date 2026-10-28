import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'morph_gesture_start/gesture_start_scene.dart';

void main() {
  for (final material in [false, true]) {
    testWidgets(
      'when ${material ? 'Material' : 'Cupertino'} Back first moves, it should paint one stationary shared element in that frame',
      (tester) async {
        tester.view.physicalSize = const Size(400, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final scene = GestureStartScene(material: material);
        await scene.open(tester);
        final gesture = await tester.startGesture(const Offset(1, 350));
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump();
        final firstFrame = await scene.painted(tester);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(firstFrame, (bounds: const Rect.fromLTWH(20, 30, 48, 48), pixels: 2304));
      },
    );
  }

  for (final scenario in [
    (name: 'large initial movement', delta: 100.0, hero: false, alternatives: false, nested: false, duration: null),
    (name: 'coexisting Hero', delta: 20.0, hero: true, alternatives: false, nested: false, duration: null),
    (name: 'alternative targets', delta: 20.0, hero: false, alternatives: true, nested: false, duration: null),
    (name: 'nested surface and header', delta: 20.0, hero: false, alternatives: false, nested: true, duration: null),
    (
      name: 'configured duration',
      delta: 20.0,
      hero: false,
      alternatives: false,
      nested: false,
      duration: const Duration(milliseconds: 600),
    ),
  ]) {
    testWidgets(
      'when Back begins with ${scenario.name}, it should paint one stationary element before any additional pump',
      (tester) async {
        tester.view.physicalSize = const Size(400, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final scene = GestureStartScene(
          withHero: scenario.hero,
          alternatives: scenario.alternatives,
          nested: scenario.nested,
          duration: scenario.duration,
        );
        await scene.open(tester);
        final gesture = await tester.startGesture(const Offset(1, 350));
        await gesture.moveBy(Offset(scenario.delta, 0));
        await tester.pump();
        final firstFrame = await scene.painted(tester);
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(
          {'painted': firstFrame, 'started': scene.started},
          {
            'painted': (bounds: const Rect.fromLTWH(20, 30, 48, 48), pixels: 2304),
            'started': ['destination'],
          },
        );
      },
    );
  }

  testWidgets('when endpoints differ, it should paint the first interactive frame at the gesture progress', (
    tester,
  ) async {
    final scene = GestureStartScene(destinationBounds: const Rect.fromLTWH(120, 130, 48, 48));
    await scene.open(tester);
    final gesture = await tester.startGesture(const Offset(1, 350));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    final firstFrame = await scene.painted(tester);
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(firstFrame, (bounds: const Rect.fromLTWH(115, 125, 48, 48), pixels: 2304));
  });

  for (final commit in [false, true]) {
    testWidgets(
      'when a slow swipe commits=$commit, it should remain stationary through reversal and deliver one start',
      (tester) async {
        tester.view.physicalSize = const Size(400, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final scene = GestureStartScene();
        await scene.open(tester);
        final gesture = await tester.startGesture(const Offset(1, 350));
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump();
        final firstFrame = await scene.painted(tester);
        await tester.pump(const Duration(milliseconds: 120));
        await gesture.moveBy(const Offset(80, 0));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        await gesture.moveBy(const Offset(-40, 0));
        await tester.pump();
        final reversed = await scene.painted(tester);
        if (commit) {
          await gesture.moveBy(const Offset(260, 0));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 120));
          await gesture.up();
        } else {
          await gesture.cancel();
        }
        await tester.pumpAndSettle();
        expect(
          {
            'first': firstFrame,
            'reversed': reversed,
            'started': scene.started,
            'status': scene.target.status.value,
            'ended': scene.ended,
          },
          {
            'first': (bounds: const Rect.fromLTWH(20, 30, 48, 48), pixels: 2304),
            'reversed': (bounds: const Rect.fromLTWH(20, 30, 48, 48), pixels: 2304),
            'started': ['destination'],
            'status': commit ? MorphTagStatus.completed : MorphTagStatus.cancelled,
            'ended': commit ? ['destination'] : <String>[],
          },
        );
      },
    );
  }

  testWidgets(
    'when a cancelled gesture is followed by another gesture, it should start each flight once without a jump',
    (tester) async {
      final scene = GestureStartScene();
      await scene.open(tester);
      final samples = <({Rect bounds, int pixels})>[];
      for (var attempt = 0; attempt < 2; attempt++) {
        final gesture = await tester.startGesture(const Offset(1, 350));
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump();
        samples.add(await scene.painted(tester));
        await gesture.cancel();
        await tester.pumpAndSettle();
      }
      expect(
        {'painted': samples, 'started': scene.started},
        {
          'painted': [
            (bounds: const Rect.fromLTWH(20, 30, 48, 48), pixels: 2304),
            (bounds: const Rect.fromLTWH(20, 30, 48, 48), pixels: 2304),
          ],
          'started': ['destination', 'destination'],
        },
      );
    },
  );

  testWidgets(
    'when a gesture is recognized without movement, it should not start a flight or invoke a start callback',
    (
      tester,
    ) async {
      final scene = GestureStartScene();
      await scene.open(tester);
      final before = scene.target.status.value;
      scene.navigator.currentState!
        ..didStartUserGesture()
        ..didStopUserGesture();
      await tester.pumpAndSettle();
      expect(
        {'started': scene.started, 'status': scene.target.status.value},
        {'started': <String>[], 'status': before},
      );
    },
  );

  for (final rejected in [false, true]) {
    testWidgets(
      'when matching is ${rejected ? 'rejected' : 'absent'}, it should retain normal route painting on the first frame',
      (tester) async {
        final scene = GestureStartScene(acceptMatch: !rejected, matched: rejected);
        await scene.open(tester);
        final gesture = await tester.startGesture(const Offset(1, 350));
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump();
        final firstFrame = await scene.painted(tester);
        await gesture.cancel();
        await tester.pumpAndSettle();
        expect(
          {'painted': firstFrame, 'started': scene.started},
          {'painted': (bounds: const Rect.fromLTWH(40, 30, 48, 48), pixels: 2304), 'started': <String>[]},
        );
      },
    );
  }

  testWidgets('when the destination was not retained, it should wait for layout before invoking a flight', (
    tester,
  ) async {
    final scene = GestureStartScene(maintainDestination: false);
    await scene.open(tester);
    final gesture = await tester.startGesture(const Offset(1, 350));
    await gesture.moveBy(const Offset(20, 0));
    final beforeLayout = scene.started.toList();
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(beforeLayout, isEmpty);
  });

  testWidgets('when motion is reduced, it should keep gesture preparation free of lifecycle callbacks', (tester) async {
    final scene = GestureStartScene(reducedMotion: true);
    await scene.open(tester);
    final gesture = await tester.startGesture(const Offset(1, 350));
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(scene.started, isEmpty);
  });
}
