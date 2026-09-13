import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

part 'morph_flight_delegate/_color_flight_delegate.dart';

void main() {
  test('when a custom delegate is const, it should support const flight configuration', () {
    const first = MorphFlightConfig.custom(_ColorFlightDelegate());
    const second = MorphFlightConfig.custom(_ColorFlightDelegate());

    expect(identical(first, second), isTrue);
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
