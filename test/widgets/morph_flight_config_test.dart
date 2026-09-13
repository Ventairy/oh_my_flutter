import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

part 'morph_flight_config/_morph_flight_config_test_app.dart';

void main() {
  test('when a Morph omits its delegate, it should use the const automatic configuration', () {
    final morphTarget1 = MorphTarget(tag: 'default');

    final morph = Morph(target: morphTarget1, child: const SizedBox());

    expect(identical(morph.flightConfig, const MorphFlightConfig.auto()), isTrue);
  });

  for (final switchAt in [0.0, 0.4, 1.0]) {
    test('when childSwitchAt is $switchAt, it should accept the configuration', () {
      expect(() => MorphFlightConfig.auto(childSwitchAt: switchAt), returnsNormally);
    });
  }

  for (final switchAt in [-0.1, 1.1, double.nan, double.infinity, double.negativeInfinity]) {
    test('when childSwitchAt is $switchAt, it should diagnose the invalid configuration', () {
      expect(() => MorphFlightConfig.auto(childSwitchAt: switchAt), throwsAssertionError);
    });
  }

  for (final explicit in [false, true]) {
    testWidgets('when automatic configuration is ${explicit ? 'explicit' : 'omitted'}, it should switch at halfway', (
      tester,
    ) async {
      final key = GlobalKey<_MorphFlightConfigTestAppState>();
      await tester.pumpWidget(
        _MorphFlightConfigTestApp(
          key: key,
          configuration: explicit ? const MorphFlightConfig.auto() : null,
        ),
      );
      await tester.pumpAndSettle();
      key.currentState!.showDestination();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 499));
      final before = find.byKey(_MorphFlightConfigTestApp.sourceKey).evaluate().length;
      await tester.pump(const Duration(milliseconds: 1));
      final at = find.byKey(_MorphFlightConfigTestApp.sourceKey).evaluate().length;
      await tester.pumpAndSettle();

      expect((before, at), (1, 0));
    });
  }

  for (final sample in [
    (milliseconds: 399, sourceCount: 1),
    (milliseconds: 400, sourceCount: 0),
    (milliseconds: 401, sourceCount: 0),
  ]) {
    testWidgets('when progress reaches ${sample.milliseconds}ms, it should select the child using childSwitchAt', (
      tester,
    ) async {
      final key = GlobalKey<_MorphFlightConfigTestAppState>();
      await tester.pumpWidget(
        _MorphFlightConfigTestApp(key: key, configuration: const .auto(childSwitchAt: 0.4)),
      );
      await tester.pumpAndSettle();
      key.currentState!.showDestination();
      await tester.pump();
      await tester.pump();
      await tester.pump(Duration(milliseconds: sample.milliseconds));
      final sourceCount = find.byKey(_MorphFlightConfigTestApp.sourceKey).evaluate().length;
      await tester.pumpAndSettle();

      expect(sourceCount, sample.sourceCount);
    });
  }

  for (final switchAt in [0.0, 1.0]) {
    testWidgets('when childSwitchAt is $switchAt, it should preserve the boundary selection', (tester) async {
      final key = GlobalKey<_MorphFlightConfigTestAppState>();
      await tester.pumpWidget(
        _MorphFlightConfigTestApp(
          key: key,
          configuration: .auto(childSwitchAt: switchAt),
        ),
      );
      await tester.pumpAndSettle();
      key.currentState!.showDestination();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final sourceCount = find.byKey(_MorphFlightConfigTestApp.sourceKey).evaluate().length;
      await tester.pumpAndSettle();

      expect(sourceCount, switchAt == 0 ? 0 : 1);
    });
  }

  testWidgets('when the movement curve reaches the switch point early, it should use curved progress', (tester) async {
    final key = GlobalKey<_MorphFlightConfigTestAppState>();
    await tester.pumpWidget(
      _MorphFlightConfigTestApp(
        key: key,
        configuration: const .auto(childSwitchAt: 0.4),
        curve: Curves.easeOutCubic,
      ),
    );
    await tester.pumpAndSettle();
    key.currentState!.showDestination();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final sourceCount = find.byKey(_MorphFlightConfigTestApp.sourceKey).evaluate().length;
    await tester.pumpAndSettle();

    expect(sourceCount, 0);
  });

  testWidgets('when automatic child content changes, it should drive the builder around childSwitchAt', (tester) async {
    final key = GlobalKey<_MorphFlightConfigTestAppState>();
    await tester.pumpWidget(
      _MorphFlightConfigTestApp(
        key: key,
        configuration: .auto(
          childSwitchAt: 0.4,
          childTransition: (child, animation) => FadeTransition(
            key: const ValueKey('child-transition'),
            opacity: animation,
            child: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    key.currentState!.showDestination();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final departing = tester.widget<FadeTransition>(find.byKey(const ValueKey('child-transition'))).opacity.value;
    await tester.pump(const Duration(milliseconds: 200));
    final atSwitch = tester.widget<FadeTransition>(find.byKey(const ValueKey('child-transition'))).opacity.value;
    await tester.pump(const Duration(milliseconds: 300));
    final arriving = tester.widget<FadeTransition>(find.byKey(const ValueKey('child-transition'))).opacity.value;
    await tester.pumpAndSettle();

    expect([departing, atSwitch, arriving], orderedEquals([0.5, 0.0, closeTo(0.5, 1e-9)]));
  });

  testWidgets('when a snapshot crosses childSwitchAt, it should switch its captured size at the same point', (
    tester,
  ) async {
    final key = GlobalKey<_MorphFlightConfigTestAppState>();
    await tester.pumpWidget(
      _MorphFlightConfigTestApp(
        key: key,
        configuration: const .auto(childSwitchAt: 0.4),
        snapshot: true,
      ),
    );
    await tester.pumpAndSettle();
    key.currentState!.showDestination();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 399));
    final snapshotPaint = find.descendant(
      of: find.byKey(_MorphFlightConfigTestApp.snapshotKey).last,
      matching: find.byType(CustomPaint),
    );
    final before = tester.getSize(snapshotPaint);
    await tester.pump(const Duration(milliseconds: 1));
    final at = tester.getSize(snapshotPaint);
    await tester.pumpAndSettle();

    expect((before, at), (const Size.square(40), const Size.square(80)));
  });
}
