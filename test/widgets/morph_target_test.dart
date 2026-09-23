import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('MorphTarget', () {
    testWidgets('when equal tags belong to different targets, it should report each connection independently', (
      tester,
    ) async {
      final matched = MorphTarget(tag: 'surface');
      final unmatched = MorphTarget(tag: 'surface');
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [MorphNavigatorObserver()],
          home: Column(
            children: [
              Morph(targets: [matched], child: const SizedBox.square(dimension: 50)),
              Morph(targets: [unmatched], child: const SizedBox.square(dimension: 50)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => Morph(targets: [matched], child: const SizedBox.square(dimension: 100)),
        ),
      );
      await tester.pumpAndSettle();
      expect((matched.status.value, unmatched.status.value), (MorphTagStatus.completed, MorphTagStatus.unmatched));
    });

    testWidgets(
      'when a listener is added before mounting, it should receive navigation updates and stop after removal',
      (tester) async {
        final target = MorphTarget(tag: 'surface');
        final status = target.status;
        final values = <MorphTagStatus>[];
        void record() => values.add(status.value);
        status.addListener(record);
        addTearDown(() => status.removeListener(record));
        final navigator = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [MorphNavigatorObserver()],
            home: Morph(targets: [target], child: const SizedBox.square(dimension: 50)),
          ),
        );
        await tester.pumpAndSettle();
        values.clear();
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => Morph(targets: [target], child: const SizedBox.square(dimension: 100)),
          ),
        );
        await tester.pumpAndSettle();
        status.removeListener(record);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(values, [MorphTagStatus.pending, MorphTagStatus.flying, MorphTagStatus.completed]);
      },
    );

    test('when duration is negative, it should reject the contract', () {
      expect(() => MorphTarget(tag: 'negative', duration: const Duration(milliseconds: -1)), throwsAssertionError);
    });

    test('when reverse duration is negative, it should reject the contract', () {
      expect(
        () => MorphTarget(
          tag: 'negative-reverse',
          reverseDuration: const Duration(milliseconds: -1),
        ),
        throwsAssertionError,
      );
    });

    test('when reverse timing is configured, it should preserve the connection contract', () {
      final target = MorphTarget(
        tag: 'asymmetric',
        reverseDuration: const Duration(milliseconds: 180),
        reverseCurve: Curves.easeIn,
      );

      expect(
        (target.reverseDuration, target.reverseCurve),
        (const Duration(milliseconds: 180), Curves.easeIn),
      );
    });

    test('when two targets share a tag, it should keep their identities distinct', () {
      final card = MorphTarget(tag: 'item');

      expect({card, MorphTarget(tag: 'item')}, hasLength(2));
    });

    test('when a target receives a tag, it should preserve its status identifier', () {
      const tag = ('item', 42);

      expect(MorphTarget(tag: tag).tag, tag);
    });

    test('when destination watching is configured, it should preserve the connection contract', () {
      expect(
        (
          MorphTarget(tag: 'stationary').watchDestination,
          MorphTarget(
            tag: 'moving',
            watchDestination: true,
          ).watchDestination,
        ),
        (false, true),
      );
    });

    testWidgets(
      'when two attached Morphs share one target, it should allow both appearances even without an Overlay',
      (tester) async {
        final target = MorphTarget(tag: 'surface');
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: Column(
              children: [
                Morph(targets: [target], child: const SizedBox.square(dimension: 50)),
                Morph(targets: [target], child: const SizedBox.square(dimension: 50)),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('when an appearance is removed, it should allow its target to be attached again', (tester) async {
      final target = MorphTarget(tag: 'surface');
      Widget appearance() => Directionality(
        textDirection: .ltr,
        child: Morph(
          targets: [target],
          child: const SizedBox.square(dimension: 50),
        ),
      );
      await tester.pumpWidget(appearance());
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(appearance());
      expect(tester.takeException(), isNull);
    });
  });
}
