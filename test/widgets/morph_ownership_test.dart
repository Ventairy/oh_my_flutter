import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import '../fixtures/morph_paint_probe/morph_paint_probe.dart';

part 'morph_ownership/_morph_ownership_app.dart';
part 'morph_ownership/_morph_ownership_scenario.dart';

void main() {
  group('Morph ownership', () {
    testWidgets('when a flight returns to a transparent route, it should keep uninvolved routes painted', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      final target = MorphTarget(
        tag: 'shared',
        canMatch: (match) => match.sourceRoute?.settings.name != '/',
      );
      var backgroundPaints = 0;
      const backgroundKey = ValueKey('background');
      await tester.pumpWidget(
        WidgetsApp(
          color: const Color(0xFFFFFFFF),
          navigatorKey: navigator,
          navigatorObservers: [MorphNavigatorObserver()],
          pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
            settings: settings,
            pageBuilder: (context, _, _) => builder(context),
          ),
          home: Morph(
            targets: [target],
            child: MorphPaintProbe(
              key: backgroundKey,
              onPaint: () => backgroundPaints++,
              child: const ColoredBox(color: Color(0xFF2468AC)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.push<void>(
        PageRouteBuilder<void>(
          opaque: false,
          pageBuilder: (_, _, _) => Align(
            alignment: .bottomCenter,
            child: Morph(
              targets: [target],
              child: const SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.push<void>(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => Morph(
            targets: [target],
            child: const SizedBox.expand(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      final paintsBeforeRepaint = backgroundPaints;
      tester.renderObject(find.byKey(backgroundKey)).markNeedsPaint();
      await tester.pump();

      expect(backgroundPaints, greaterThan(paintsBeforeRepaint));
    });

    testWidgets('when another appearance mounts, it should receive the shared visual', (tester) async {
      final scenario = _MorphOwnershipScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      await scenario.show(tester, [scenario.a, scenario.b]);

      expect(scenario.received, ['B']);
    });

    testWidgets('when the owner is removed, it should return to the previous mounted appearance', (tester) async {
      final scenario = _MorphOwnershipScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      await scenario.show(tester, [scenario.a, scenario.b]);
      scenario.received.clear();
      await scenario.show(tester, [scenario.a]);

      expect(scenario.received, ['A']);
    });

    testWidgets('when a covered appearance is removed, it should leave the current owner unchanged', (tester) async {
      final scenario = _MorphOwnershipScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      await scenario.show(tester, [scenario.a, scenario.b]);
      scenario.started.clear();
      await scenario.show(tester, [scenario.b]);

      expect(scenario.started, isEmpty);
    });

    testWidgets('when several appearances mount together, it should animate directly to the last one', (tester) async {
      final scenario = _MorphOwnershipScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      await scenario.show(tester, [scenario.a, scenario.b, scenario.c]);

      expect(scenario.started, ['A']);
    });

    testWidgets('when a coalesced destination is removed, it should reveal the preceding mounted appearance', (
      tester,
    ) async {
      final scenario = _MorphOwnershipScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      await scenario.show(tester, [scenario.a, scenario.b, scenario.c]);
      scenario.received.clear();
      await scenario.show(tester, [scenario.a, scenario.b]);

      expect(scenario.received, ['B']);
    });

    testWidgets('when mounted appearances rebuild, it should preserve their ownership order', (tester) async {
      final scenario = _MorphOwnershipScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      await scenario.show(tester, [scenario.a, scenario.b]);
      scenario.started.clear();
      await scenario.show(tester, [scenario.b, scenario.a]);

      expect(scenario.started, isEmpty);
    });

    testWidgets(
      'when an arrival is removed before the frame builds, it should retain the previous owner without a flight',
      (tester) async {
        final scenario = _MorphOwnershipScenario();
        await tester.pumpWidget(scenario.app);
        await tester.pumpAndSettle();
        scenario.appearances.value = [scenario.a, scenario.b];
        scenario.appearances.value = [scenario.a];
        await tester.pumpAndSettle();

        expect(scenario.started, isEmpty);
      },
    );

    testWidgets('when a covered parent mounts a child appearance, it should preserve foreground child ownership', (
      tester,
    ) async {
      final parentA = MorphTarget(tag: 'parent');

      final childA = MorphTarget(tag: 'child');

      final started = <MorphTarget>[];
      var addCoveredChild = false;
      late StateSetter update;
      Widget parent(MorphTarget target, List<MorphTarget> children) => Morph(
        targets: [target],
        child: Container(
          key: ObjectKey(target),
          width: 240,
          height: 240,
          color: const Color(0xFFEEEEEE),
          child: Column(
            children: [
              for (final (index, child) in children.indexed)
                Morph(
                  key: ValueKey(index),
                  targets: [child],
                  onStart: () => started.add(child),
                  child: SizedBox(key: ObjectKey(child), width: 80, height: 80),
                ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (_) => StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: [
                        Positioned(left: 20, top: 40, child: parent(parentA, [childA, if (addCoveredChild) childA])),
                        Positioned(left: 300, top: 40, child: parent(parentA, [childA])),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      started.clear();
      update(() => addCoveredChild = true);
      await tester.pumpAndSettle();

      expect(started, isEmpty);
    });

    testWidgets(
      'when a nested appearance matches its parent tag, it should select the new appearance without a cycle',
      (tester) async {
        final parent = MorphTarget(tag: 'surface');

        var showChild = false;
        late StateSetter update;
        var received = false;
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (_) => StatefulBuilder(
                    builder: (context, setState) {
                      update = setState;
                      return Center(
                        child: Morph(
                          targets: [parent],
                          child: SizedBox(
                            key: const ValueKey('parent'),
                            width: 200,
                            height: 200,
                            child: showChild
                                ? Center(
                                    child: Morph(
                                      targets: [parent],
                                      onReceived: () => received = true,
                                      child: const SizedBox(width: 100, height: 100),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        update(() => showChild = true);
        await tester.pumpAndSettle();

        expect(received, isTrue);
      },
    );
  });
}
