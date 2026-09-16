import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

part 'morph_flight_delegate/_color_flight_delegate.dart';
part 'morph_flight_delegate/_independent_flight_delegate.dart';

void main() {
  test('when a custom delegate is const, it should support const flight configuration', () {
    const first = MorphFlightConfig.custom(_ColorFlightDelegate());
    const second = MorphFlightConfig.custom(_ColorFlightDelegate());

    expect(identical(first, second), isTrue);
  });

  for (final interrupt in [false, true]) {
    testWidgets(
      'when ${interrupt ? 'interrupting a push' : 'returning after completion'}, it should expose the existing flight kind and playback',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        final delegate = _IndependentFlightDelegate();
        final firstTarget = MorphTarget(tag: 'independent');
        final secondTarget = MorphTarget(tag: 'independent');
        Widget endpoint(MorphTarget target, double width) => Center(
          child: Morph(
            target: target,
            duration: const Duration(seconds: 1),
            curve: Curves.easeIn,
            flightConfig: .custom(delegate),
            child: SizedBox(width: width, height: 80),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            navigatorObservers: [MorphNavigatorObserver()],
            home: endpoint(firstTarget, 80),
          ),
        );
        await tester.pumpAndSettle();
        navigator.currentState!.push(
          PageRouteBuilder<void>(
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, _, _) => endpoint(secondTarget, 160),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        final opening = delegate.progress!;
        if (!interrupt) await tester.pumpAndSettle();
        navigator.currentState!.pop();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final returning = delegate.progress!;
        await tester.pumpAndSettle();
        expect(
          (
            opening.flightKind,
            opening.animationStatus,
            opening.uncurvedProgress,
            opening.curvedProgress,
            returning.flightKind,
            returning.animationStatus,
          ),
          (
            MorphFlightKind.routePush,
            AnimationStatus.forward,
            .25,
            Curves.easeIn.transform(.25),
            interrupt ? MorphFlightKind.routePush : MorphFlightKind.routePop,
            interrupt ? AnimationStatus.reverse : AnimationStatus.forward,
          ),
        );
      },
    );
  }

  testWidgets('when a same-screen flight reverses, it should retain its kind and expose reverse playback', (
    tester,
  ) async {
    final delegate = _IndependentFlightDelegate();
    final first = MorphTarget(tag: 'same-screen');
    final second = MorphTarget(tag: 'same-screen');
    var destination = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [MorphNavigatorObserver()],
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Center(
              child: Morph(
                key: ValueKey(destination),
                target: destination ? second : first,
                duration: const Duration(seconds: 1),
                curve: Curves.easeIn,
                flightConfig: .custom(delegate),
                child: SizedBox(key: ValueKey(destination), width: destination ? 160 : 80, height: 80),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    update(() => destination = true);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    update(() => destination = false);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final progress = delegate.progress!;
    await tester.pumpAndSettle();
    expect((progress.flightKind, progress.animationStatus), (MorphFlightKind.sameScreen, AnimationStatus.reverse));
  });

  testWidgets('when independently timed content is retargeted, it should sample the visible value', (tester) async {
    final delegate = _IndependentFlightDelegate();
    final target = MorphTarget(tag: 'retarget');
    var width = 80.0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [MorphNavigatorObserver()],
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Center(
              child: Morph(
                target: target,
                animateChildChanges: true,
                duration: const Duration(seconds: 1),
                curve: Curves.easeIn,
                flightConfig: .custom(delegate),
                child: SizedBox(width: width, height: 80),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    update(() => width = 160);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final visible = delegate.flights.last.properties;
    update(() => width = 240);
    await tester.pump();
    await tester.pump();
    final sampled = delegate.flights.last.source.properties;
    await tester.pumpAndSettle();
    expect((visible, sampled), (100.0, 100.0));
  });

  for (final curve in [Curves.linear, Curves.easeIn, Curves.easeOutBack]) {
    testWidgets('when a custom flight uses $curve, it should expose both animations and interpolate with the curve', (
      tester,
    ) async {
      final morphTarget1 = MorphTarget(tag: 'custom-config');
      final morphObserver1 = MorphNavigatorObserver();

      final captures = <Color>[];
      late MorphFlight<Color> flight;
      final delegate = _ColorFlightDelegate(
        onCapture: captures.add,
        onBuild: (value) => flight = value,
      );
      var destination = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [morphObserver1],
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Center(
                child: Morph(
                  animateChildChanges: true,
                  target: morphTarget1,
                  duration: const Duration(seconds: 1),
                  curve: curve,
                  flightConfig: .custom(delegate),
                  child: ColoredBox(
                    color: destination ? Colors.blue : Colors.red,
                    child: const SizedBox.square(dimension: 80),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      update(() => destination = true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      final flightColor = tester.widget<ColoredBox>(find.byKey(const ValueKey('custom-flight'))).color;
      final progress = (flight.curvedAnimation.value, flight.uncurvedAnimation.value);
      await tester.pumpAndSettle();

      expect(
        (captures.contains(Colors.red), captures.contains(Colors.blue), flightColor, progress),
        (true, true, Color.lerp(Colors.red, Colors.blue, curve.transform(0.25)), (curve.transform(0.25), 0.25)),
      );
    });
  }
}
