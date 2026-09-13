import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

part 'morph_ownership/_morph_ownership_app.dart';
part 'morph_ownership/_morph_ownership_scenario.dart';

void main() {
  group('Morph ownership', () {
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

    testWidgets('when appearances share a route, it should give their siblings opposite progress', (tester) async {
      final scenario = _MorphOwnershipScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.appearances.value = [scenario.a, scenario.b];
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(scenario.values, {'A': (0.75, 0.75), 'B': (0.25, 0.25)});
    });

    testWidgets('when a target only replaces its child, it should keep its sibling fully present', (tester) async {
      final scenario = _MorphOwnershipScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.revision.value += 1;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(scenario.values, {'A': (1.0, 1.0)});
    });

    testWidgets('when another target interrupts a flight, it should preserve every mounted sibling value', (
      tester,
    ) async {
      final scenario = _MorphOwnershipScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.appearances.value = [scenario.a, scenario.b];
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final previous = scenario.values;
      scenario.appearances.value = [scenario.a, scenario.b, scenario.c];
      await tester.pump();

      expect(scenario.values, {...previous, 'C': (0.0, 0.0)});
    });

    testWidgets('when a curved flight is interrupted, it should preserve the two independently sampled values', (
      tester,
    ) async {
      final scenario = _MorphOwnershipScenario(curve: Curves.easeIn);
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      scenario.appearances.value = [scenario.a, scenario.b];
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final before = scenario.values;
      scenario.appearances.value = [scenario.a, scenario.b, scenario.c];
      await tester.pump();

      expect(
        [scenario.values, before['B']!.$1 < before['B']!.$2],
        [
          {...before, 'C': (0.0, 0.0)},
          true,
        ],
      );
    });

    testWidgets(
      'when a body replacement interrupts arrival, it should continue sibling timing through the replacement',
      (tester) async {
        final scenario = _MorphOwnershipScenario();
        await tester.pumpWidget(scenario.app);
        await tester.pumpAndSettle();
        scenario.appearances.value = [scenario.a, scenario.b];
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        scenario.revision.value += 1;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(scenario.values, {'A': (0.5, 0.5), 'B': (0.5, 0.5)});
      },
    );

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

    testWidgets(
      'when an interrupted destination disappears, it should return every surviving sibling to its resting value',
      (tester) async {
        final scenario = _MorphOwnershipScenario(curve: Curves.easeIn);
        await tester.pumpWidget(scenario.app);
        await tester.pumpAndSettle();
        scenario.appearances.value = [scenario.a, scenario.b];
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        scenario.appearances.value = [scenario.a, scenario.b, scenario.c];
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await scenario.show(tester, [scenario.a, scenario.b]);

        expect(scenario.values, {'A': (0.0, 0.0), 'B': (1.0, 1.0)});
      },
    );

    testWidgets('when a covered parent mounts a child appearance, it should preserve foreground child ownership', (
      tester,
    ) async {
      final parentA = MorphTarget(tag: 'parent');
      final parentB = MorphTarget(tag: 'parent');
      final childA = MorphTarget(tag: 'child');
      final childB = MorphTarget(tag: 'child');
      final childC = MorphTarget(tag: 'child');
      final started = <MorphTarget>[];
      var addCoveredChild = false;
      late StateSetter update;
      Widget parent(MorphTarget target, List<MorphTarget> children) => Morph(
        target: target,
        child: Container(
          key: ObjectKey(target),
          width: 240,
          height: 240,
          color: const Color(0xFFEEEEEE),
          child: Column(
            children: [
              for (final child in children)
                Morph(
                  key: ObjectKey(child),
                  target: child,
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
                        Positioned(left: 20, top: 40, child: parent(parentA, [childA, if (addCoveredChild) childC])),
                        Positioned(left: 300, top: 40, child: parent(parentB, [childB])),
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
        final child = MorphTarget(tag: 'surface');
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
                          target: parent,
                          child: SizedBox(
                            key: const ValueKey('parent'),
                            width: 200,
                            height: 200,
                            child: showChild
                                ? Center(
                                    child: Morph(
                                      target: child,
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

    testWidgets('when a flight settles, it should keep only the current target sibling present', (tester) async {
      final scenario = _MorphOwnershipScenario();
      await tester.pumpWidget(scenario.app);
      await tester.pumpAndSettle();
      await scenario.show(tester, [scenario.a, scenario.b]);

      expect(scenario.values, {'A': (0.0, 0.0), 'B': (1.0, 1.0)});
    });
  });
}
