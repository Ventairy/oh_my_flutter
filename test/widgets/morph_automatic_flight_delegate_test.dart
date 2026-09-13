import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  late ValueNotifier<int> endpoint;

  setUp(() => endpoint = ValueNotifier(0));
  tearDown(() => endpoint.dispose());

  final snapshotPaints = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter.runtimeType.toString() == '_MorphContentSnapshotPainter',
  );

  Future<void> startFlight(
    WidgetTester tester, {
    required Widget Function({required bool expanded}) contentBuilder,
  }) async {
    final morphTarget1 = MorphTarget(tag: 'automatic-content');
    final morphObserver1 = MorphNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [morphObserver1],
        home: Align(
          child: ValueListenableBuilder<int>(
            valueListenable: endpoint,
            builder: (context, value, _) => Morph(
              animateChildChanges: true,
              target: morphTarget1,
              duration: const Duration(seconds: 1),
              flightConfig: const .auto(childSwitchAt: 0.8),
              child: SizedBox(
                key: ValueKey(value),
                width: value > 0 ? 200 : 160,
                height: value > 0 ? 140 : 120,
                child: contentBuilder(expanded: value > 0),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    endpoint.value = 1;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  List<Size> snapshotSizes(WidgetTester tester) => snapshotPaints.evaluate().map((element) {
    return tester.getSize(find.byWidget(element.widget));
  }).toList();

  Future<void> retargetRepeatedly(WidgetTester tester) async {
    for (var target = 2; target <= 8; target++) {
      endpoint.value = target;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  const repeatedDescendant = MorphDescendant(
    flightBehavior: .snapshot,
    child: SizedBox.expand(child: ColoredBox(color: Colors.blue)),
  );

  testWidgets(
    'when a generic automatic subtree repeats one snapshot widget, it should preserve each occurrence size',
    (tester) async {
      await startFlight(
        tester,
        contentBuilder: ({required expanded}) => const Row(
          children: [
            SizedBox(width: 20, height: 30, child: repeatedDescendant),
            SizedBox(width: 40, height: 50, child: repeatedDescendant),
          ],
        ),
      );

      expect(snapshotSizes(tester), [const Size(20, 30), const Size(40, 50)]);
    },
  );

  testWidgets(
    'when an automatic Column repeats a snapshot widget inside different wrappers, it should keep their sizes',
    (tester) async {
      await startFlight(
        tester,
        contentBuilder: ({required expanded}) => const Column(
          children: [
            SizedBox(width: 20, height: 30, child: repeatedDescendant),
            SizedBox(width: 40, height: 50, child: repeatedDescendant),
          ],
        ),
      );

      expect(snapshotSizes(tester), [const Size(20, 30), const Size(40, 50)]);
    },
  );

  testWidgets(
    'when automatic content rebuilds unkeyed snapshot descendants, it should preserve their source sizes',
    (tester) async {
      await startFlight(
        tester,
        contentBuilder: ({required expanded}) => LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              for (final size in [const Size(20, 30), const Size(40, 50)])
                SizedBox.fromSize(
                  size: expanded ? size * 1.5 : size,
                  child: MorphDescendant(
                    flightBehavior: .snapshot,
                    child: ColoredBox(color: expanded ? Colors.green : Colors.blue),
                  ),
                ),
            ],
          ),
        ),
      );

      expect(snapshotSizes(tester), [const Size(20, 30), const Size(40, 50)]);
    },
  );

  testWidgets(
    'when an automatic flight retargets after switching content, it should keep the selected snapshot visible',
    (tester) async {
      await startFlight(tester, contentBuilder: ({required expanded}) => repeatedDescendant);
      await tester.pump(const Duration(milliseconds: 650));
      endpoint.value = 2;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(snapshotPaints, findsOneWidget);
    },
  );

  for (final remove in [false, true]) {
    testWidgets(
      'when an automatic flight ${remove ? 'is removed during retargeting' : 'settles after retargeting'}, '
      'it should release all captured images',
      (tester) async {
        final images = <ui.Image>{};
        final previousOnCreate = ui.Image.onCreate;
        final previousOnDispose = ui.Image.onDispose;
        ui.Image.onCreate = (image) {
          previousOnCreate?.call(image);
          images.add(image);
        };
        ui.Image.onDispose = (image) {
          previousOnDispose?.call(image);
          images.remove(image);
        };
        addTearDown(() {
          ui.Image.onCreate = previousOnCreate;
          ui.Image.onDispose = previousOnDispose;
        });
        await startFlight(tester, contentBuilder: ({required expanded}) => repeatedDescendant);
        await retargetRepeatedly(tester);
        if (remove) await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        expect(images, isEmpty);
      },
    );
  }

  testWidgets(
    'when an automatic flight retargets repeatedly, it should keep snapshot retention bounded',
    (tester) async {
      final images = <ui.Image>{};
      var peakImages = 0;
      final previousOnCreate = ui.Image.onCreate;
      final previousOnDispose = ui.Image.onDispose;
      ui.Image.onCreate = (image) {
        previousOnCreate?.call(image);
        images.add(image);
        if (images.length > peakImages) peakImages = images.length;
      };
      ui.Image.onDispose = (image) {
        previousOnDispose?.call(image);
        images.remove(image);
      };
      addTearDown(() {
        ui.Image.onCreate = previousOnCreate;
        ui.Image.onDispose = previousOnDispose;
      });
      await startFlight(tester, contentBuilder: ({required expanded}) => repeatedDescendant);
      await retargetRepeatedly(tester);

      // Two active endpoints and temporary replacements fit within four images.
      expect(peakImages, lessThanOrEqualTo(4));
    },
  );
}
