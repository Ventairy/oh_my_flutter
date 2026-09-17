import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

part 'morph_registered_descendant/_snapshot_flight_delegate.dart';
part 'morph_registered_descendant/_snapshot_flight_harness.dart';
part 'morph_registered_descendant/_split_flight_delegate.dart';
part 'morph_registered_descendant/_split_flight_types.dart';
part 'morph_registered_descendant/_split_flight_properties.dart';
part 'morph_registered_descendant/_split_class_flight_delegate.dart';

void main() {
  testWidgets(
    'when a keyed endpoint is removed, it should retain its last-painted snapshot for a custom crossfade',
    (tester) async {
      final destination = ValueNotifier(false);
      addTearDown(destination.dispose);
      final sourceTarget = MorphTarget(tag: 'replacement');
      final destinationTarget = MorphTarget(tag: 'replacement');
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [MorphNavigatorObserver()],
          home: ValueListenableBuilder<bool>(
            valueListenable: destination,
            builder: (context, value, child) => Center(
              child: Morph(
                animateChildChanges: true,
                key: ValueKey(value),
                target: value ? destinationTarget : sourceTarget,
                duration: const Duration(seconds: 1),
                flightConfig: const MorphFlightConfig.custom(_SnapshotFlightDelegate(crossFade: true)),
                child: SizedBox(
                  width: value ? 120 : 80,
                  height: value ? 90 : 60,
                  child: MorphDescendant(
                    flightBehavior: MorphDescendantFlightBehavior.snapshot,
                    child: ColoredBox(color: value ? Colors.blue : Colors.red),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      destination.value = true;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.painter.runtimeType.toString() == '_MorphContentSnapshotPainter',
        ),
        findsNWidgets(2),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'when a custom delegate keeps its source until 80 percent, '
    'it should keep the source snapshot after halfway',
    (tester) async {
      final key = GlobalKey<_SnapshotFlightHarnessState>();
      await tester.pumpWidget(_SnapshotFlightHarness(key: key));
      await tester.pumpAndSettle();
      key.currentState!.show(1);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));

      expect((await key.currentState!.snapshotColor(tester)).toARGB32(), 0xfff44336);
    },
  );

  for (final (:switchAt, :milliseconds, :expected) in [
    (switchAt: 0.8, milliseconds: 850, expected: 0xff2196f3),
    (switchAt: 0.2, milliseconds: 350, expected: 0xff2196f3),
  ]) {
    testWidgets(
      'when a custom delegate switches at $switchAt, '
      'it should show the destination snapshot at ${milliseconds}ms',
      (tester) async {
        final key = GlobalKey<_SnapshotFlightHarnessState>();
        await tester.pumpWidget(
          _SnapshotFlightHarness(
            key: key,
            delegate: _SnapshotFlightDelegate(switchAt: switchAt),
          ),
        );
        await tester.pumpAndSettle();
        key.currentState!.show(1);
        await tester.pump();
        await tester.pump();
        await tester.pump(Duration(milliseconds: milliseconds));

        expect((await key.currentState!.snapshotColor(tester)).toARGB32(), expected);
      },
    );
  }

  testWidgets(
    'when both endpoints register the same widget, it should select the captured endpoint size',
    (tester) async {
      final key = GlobalKey<_SnapshotFlightHarnessState>();
      await tester.pumpWidget(_SnapshotFlightHarness(key: key, sharedDescendant: true));
      await tester.pumpAndSettle();
      key.currentState!.show(1);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      final sourceSize = tester.getSize(key.currentState!.snapshotPaints);
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        (sourceSize, tester.getSize(key.currentState!.snapshotPaints)),
        (const Size(80, 60), const Size(120, 90)),
      );
    },
  );

  for (final usesUncurvedAnimation in [false, true]) {
    testWidgets(
      'when content uses ${usesUncurvedAnimation ? 'uncurved' : 'curved'} progress with an eased flight, '
      'it should follow the selected registered widget',
      (tester) async {
        final key = GlobalKey<_SnapshotFlightHarnessState>();
        await tester.pumpWidget(
          _SnapshotFlightHarness(
            key: key,
            curve: Curves.easeOut,
            delegate: _SnapshotFlightDelegate(usesUncurvedAnimation: usesUncurvedAnimation),
          ),
        );
        await tester.pumpAndSettle();
        key.currentState!.show(1);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 650));

        expect(
          (await key.currentState!.snapshotColor(tester)).toARGB32(),
          usesUncurvedAnimation ? 0xfff44336 : 0xff2196f3,
        );
      },
    );
  }

  testWidgets(
    'when a custom flight crossfades its endpoints, it should paint both endpoint snapshots independently',
    (tester) async {
      final key = GlobalKey<_SnapshotFlightHarnessState>();
      await tester.pumpWidget(
        _SnapshotFlightHarness(key: key, delegate: const _SnapshotFlightDelegate(crossFade: true)),
      );
      await tester.pumpAndSettle();
      key.currentState!.show(1);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final sourceColor = await key.currentState!.snapshotColor(tester);
      final destinationColor = await key.currentState!.snapshotColor(tester, index: 1);

      expect(
        (
          sourceColor.r > sourceColor.b,
          destinationColor.b > destinationColor.r,
          tester.getSize(key.currentState!.snapshotPaints.first),
          tester.getSize(key.currentState!.snapshotPaints.last),
        ),
        (true, true, const Size(80, 60), const Size(120, 90)),
      );
    },
  );

  for (final behavior in [MorphDescendantFlightBehavior.snapshot, MorphDescendantFlightBehavior.hide]) {
    testWidgets(
      'when a custom flight renders unregistered $behavior content, it should explain how to register the subtree',
      (tester) async {
        final key = GlobalKey<_SnapshotFlightHarnessState>();
        await tester.pumpWidget(
          _SnapshotFlightHarness(
            key: key,
            behavior: behavior,
            delegate: const _SnapshotFlightDelegate(register: false),
          ),
        );
        await tester.pumpAndSettle();
        key.currentState!.show(1);
        await tester.pump();
        await tester.pump();

        expect(tester.takeException().toString(), contains('endpoint.descendantWidget'));
      },
    );
  }

  testWidgets(
    'when a custom flight renders unregistered live content, it should keep the content usable',
    (tester) async {
      final key = GlobalKey<_SnapshotFlightHarnessState>();
      await tester.pumpWidget(
        _SnapshotFlightHarness(
          key: key,
          behavior: .live,
          delegate: const _SnapshotFlightDelegate(register: false),
        ),
      );
      await tester.pumpAndSettle();
      key.currentState!.show(1);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));

      expect(
        (
          tester.takeException(),
          find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color == Colors.red).evaluate().length,
        ),
        (null, 1),
      );
    },
  );

  testWidgets(
    'when registered hidden content switches endpoints, it should reserve endpoint space within the flight constraints',
    (tester) async {
      final key = GlobalKey<_SnapshotFlightHarnessState>();
      await tester.pumpWidget(_SnapshotFlightHarness(key: key, behavior: .hide));
      await tester.pumpAndSettle();
      key.currentState!.show(1);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      final hidden = find.descendant(
        of: find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_MorphRegisteredDescendant'),
        matching: find.byType(MorphDescendant),
      );
      final sourceSize = tester.getSize(hidden);
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        (sourceSize, tester.getSize(hidden), key.currentState!.snapshotPaints.evaluate().length),
        (const Size(80, 60), const Size(114, 85.5), 0),
      );
    },
  );

  for (final interruptPush in [false, true]) {
    testWidgets(
      'when a registered route flight ${interruptPush ? 'reverses before arrival' : 'pushes and pops'}, '
      'it should preserve the selected snapshot and the original scroll state',
      (tester) async {
        final morphObserver1 = MorphNavigatorObserver();

        final navigatorKey = GlobalKey<NavigatorState>();
        final sourceController = ScrollController(initialScrollOffset: 20);
        final destinationController = ScrollController();
        addTearDown(sourceController.dispose);
        addTearDown(destinationController.dispose);
        Widget endpoint(int index) {
          final morphTarget1 = MorphTarget(tag: 'registered-route');
          return Align(
            child: Morph(
              animateChildChanges: true,
              target: morphTarget1,
              flightConfig: const .custom(_SnapshotFlightDelegate()),
              child: SizedBox(
                width: index == 0 ? 80 : 120,
                height: index == 0 ? 60 : 90,
                child: MorphDescendant(
                  flightBehavior: .snapshot,
                  child: SingleChildScrollView(
                    controller: index == 0 ? sourceController : destinationController,
                    child: SizedBox(
                      height: 400,
                      child: ColoredBox(color: index == 0 ? Colors.red : Colors.blue),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [morphObserver1],
            navigatorKey: navigatorKey,
            home: Scaffold(body: endpoint(0)),
          ),
        );
        await tester.pumpAndSettle();
        navigatorKey.currentState!.push<void>(
          PageRouteBuilder<void>(
            opaque: false,
            transitionDuration: const Duration(seconds: 1),
            reverseTransitionDuration: const Duration(seconds: 1),
            pageBuilder: (context, animation, secondaryAnimation) => endpoint(1),
            transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 850));
        if (!interruptPush) await tester.pumpAndSettle();
        navigatorKey.currentState!.pop();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final snapshotSize = tester.getSize(
          find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint && widget.painter.runtimeType.toString() == '_MorphContentSnapshotPainter',
          ),
        );
        await tester.pumpAndSettle();

        expect(
          (snapshotSize, sourceController.positions.length, sourceController.offset),
          (interruptPush ? const Size(80, 60) : const Size(120, 90), 1, 20.0),
        );
      },
    );
  }

  testWidgets(
    'when registered destination content changes during a watched flight, it should refresh its image and size',
    (tester) async {
      final key = GlobalKey<_SnapshotFlightHarnessState>();
      await tester.pumpWidget(_SnapshotFlightHarness(key: key, watchDestination: true));
      await tester.pumpAndSettle();
      key.currentState!.show(1);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 850));
      key.currentState!.updateDestination(sizeChange: const Size(30, 20), color: Colors.green);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(
        ((await key.currentState!.snapshotColor(tester)).toARGB32(), tester.getSize(key.currentState!.snapshotPaints)),
        (0xff4caf50, const Size(150, 110)),
      );
    },
  );

  testWidgets(
    'when a registered flight reverses across its switch, it should return to the source snapshot',
    (tester) async {
      final key = GlobalKey<_SnapshotFlightHarnessState>();
      await tester.pumpWidget(_SnapshotFlightHarness(key: key));
      await tester.pumpAndSettle();
      key.currentState!.show(1);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 850));
      key.currentState!.show(0);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect((await key.currentState!.snapshotColor(tester)).toARGB32(), 0xfff44336);
    },
  );

  testWidgets(
    'when a registered flight retargets, it should retain the selected snapshot until the next switch',
    (tester) async {
      final key = GlobalKey<_SnapshotFlightHarnessState>();
      await tester.pumpWidget(_SnapshotFlightHarness(key: key));
      await tester.pumpAndSettle();
      key.currentState!.show(1);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 850));
      key.currentState!.show(2);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));
      final retained = (await key.currentState!.snapshotColor(tester)).toARGB32();
      await tester.pump(const Duration(milliseconds: 200));

      expect((retained, (await key.currentState!.snapshotColor(tester)).toARGB32()), (0xff2196f3, 0xff4caf50));
    },
  );

  for (final cancel in [false, true]) {
    testWidgets(
      'when a registered flight ${cancel ? 'is removed' : 'completes after retargeting'}, it should release its images',
      (tester) async {
        final key = GlobalKey<_SnapshotFlightHarnessState>();
        await tester.pumpWidget(_SnapshotFlightHarness(key: key));
        await tester.pumpAndSettle();
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
        key.currentState!.show(1);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 650));
        key.currentState!.show(2);
        await tester.pump();
        await tester.pump();
        if (cancel) await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        expect(images, isEmpty);
      },
    );
  }

  for (final delegate in <MorphFlightDelegate<Object?>>[
    const _SplitFlightDelegate(),
    const _SplitClassFlightDelegate(),
  ]) {
    testWidgets(
      'when ${delegate.runtimeType} switches two registered pieces independently, '
      'it should keep each piece paired with its own snapshot',
      (tester) async {
        final key = GlobalKey<_SnapshotFlightHarnessState>();
        await tester.pumpWidget(
          _SnapshotFlightHarness(
            key: key,
            delegate: delegate,
            contentBuilder: (endpoint) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: MorphDescendant(
                    flightBehavior: .snapshot,
                    child: ColoredBox(color: endpoint == 0 ? Colors.red : Colors.blue),
                  ),
                ),
                Expanded(
                  child: MorphDescendant(
                    flightBehavior: .snapshot,
                    child: ColoredBox(color: endpoint == 0 ? Colors.yellow : Colors.green),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        key.currentState!.show(1);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          (
            (await key.currentState!.snapshotColor(tester)).toARGB32(),
            (await key.currentState!.snapshotColor(tester, index: 1)).toARGB32(),
          ),
          (0xff2196f3, 0xffffeb3b),
        );
      },
    );
  }

  testWidgets(
    'when registered content rebuilds keyed descendants in another order, it should keep their source images',
    (tester) async {
      final key = GlobalKey<_SnapshotFlightHarnessState>();
      await tester.pumpWidget(
        _SnapshotFlightHarness(
          key: key,
          contentBuilder: (endpoint) => LayoutBuilder(
            builder: (context, constraints) {
              final children = [
                Expanded(
                  child: MorphDescendant(
                    key: const ValueKey('first'),
                    flightBehavior: .snapshot,
                    child: ColoredBox(color: endpoint == 0 ? Colors.red : Colors.blue),
                  ),
                ),
                Expanded(
                  child: MorphDescendant(
                    key: const ValueKey('second'),
                    flightBehavior: .snapshot,
                    child: ColoredBox(color: endpoint == 0 ? Colors.yellow : Colors.green),
                  ),
                ),
              ];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: constraints.maxWidth > 100 ? children.reversed.toList() : children,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      key.currentState!.show(1);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));

      expect(
        (
          (await key.currentState!.snapshotColor(tester)).toARGB32(),
          (await key.currentState!.snapshotColor(tester, index: 1)).toARGB32(),
        ),
        (0xffffeb3b, 0xfff44336),
      );
    },
  );

  testWidgets(
    'when separately registered subtrees reuse a local key, it should match each subtree by identity',
    (tester) async {
      final key = GlobalKey<_SnapshotFlightHarnessState>();
      const sharedDescendant = MorphDescendant(
        flightBehavior: MorphDescendantFlightBehavior.snapshot,
        child: SizedBox.expand(child: ColoredBox(color: Colors.blue)),
      );
      await tester.pumpWidget(
        _SnapshotFlightHarness(
          key: key,
          delegate: const _SplitFlightDelegate(),
          contentBuilder: (endpoint) => const Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  key: ValueKey('local'),
                  padding: EdgeInsets.zero,
                  child: sharedDescendant,
                ),
              ),
              Expanded(
                child: Padding(
                  key: ValueKey('local'),
                  padding: EdgeInsets.all(4),
                  child: sharedDescendant,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      key.currentState!.show(1);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        key.currentState!.snapshotPaints.evaluate().map((element) => (element.renderObject! as RenderBox).size),
        [const Size(60, 90), const Size(32, 52)],
      );
    },
  );

  testWidgets(
    'when registered content contains a nested Morph, it should preserve that Morph descendant ownership',
    (tester) async {
      final morphTarget2 = MorphTarget(tag: 'idle-nested');

      final key = GlobalKey<_SnapshotFlightHarnessState>();
      await tester.pumpWidget(
        _SnapshotFlightHarness(
          key: key,
          contentBuilder: (endpoint) => Row(
            key: const ValueKey('registered-content'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: MorphDescendant(
                  key: const ValueKey('shared-key'),
                  flightBehavior: .snapshot,
                  child: ColoredBox(color: endpoint == 0 ? Colors.red : Colors.blue),
                ),
              ),
              Expanded(
                child: Morph(
                  animateChildChanges: true,
                  target: morphTarget2,
                  child: const MorphDescendant(
                    key: ValueKey('shared-key'),
                    flightBehavior: .snapshot,
                    child: ColoredBox(color: Colors.green),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      key.currentState!.show(1);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 650));

      final registration = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_MorphRegisteredDescendant',
      );
      final content = find.descendant(of: registration, matching: find.byKey(const ValueKey('registered-content')));
      expect(
        (
          find.descendant(of: content, matching: key.currentState!.snapshotPaints).evaluate().length,
          find
              .descendant(
                of: content,
                matching: find.byWidgetPredicate((widget) => widget is ColoredBox && widget.color == Colors.green),
              )
              .evaluate()
              .length,
        ),
        (1, 1),
      );
    },
  );
}
