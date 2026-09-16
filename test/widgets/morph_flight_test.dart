import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

part 'morph_flight/_counting_flight_delegate.dart';

void main() {
  group('MorphFlight', () {
    late MorphEndpoint<double> source;
    late MorphEndpoint<double> destination;

    setUp(() {
      source = MorphEndpoint<double>(
        properties: 0,
        bounds: const Rect.fromLTWH(0, 0, 40, 40),
        localSize: const Size(40, 40),
        transform: Matrix4.identity(),
        axisScale: const Offset(1, 1),
      );
      destination = MorphEndpoint<double>(
        properties: 1,
        bounds: const Rect.fromLTWH(80, 80, 120, 120),
        localSize: const Size(120, 120),
        transform: Matrix4.identity(),
        axisScale: const Offset(1, 1),
      );
    });

    test(
      'when properties is read repeatedly at one progress, it should interpolate once',
      () {
        final delegate = _CountingFlightDelegate();
        final flight = MorphFlight<double>(
          source: source,
          destination: destination,
          kind: MorphFlightKind.sameScreen,
          curvedAnimation: const AlwaysStoppedAnimation<double>(0.5),
          uncurvedAnimation: const AlwaysStoppedAnimation<double>(0.5),
          flightDelegate: delegate,
        );

        final values = (flight.properties, flight.properties);

        expect((values, delegate.interpolationCount), ((0.5, 0.5), 1));
      },
    );

    for (final changeStatus in [false, true]) {
      testWidgets(
        'when ${changeStatus ? 'status' : 'uncurved progress'} changes at fixed curved progress, it should invalidate properties',
        (tester) async {
          final animation = AnimationController(vsync: tester, duration: const Duration(seconds: 1), value: .25);
          addTearDown(animation.dispose);
          final delegate = _CountingFlightDelegate();
          final flight = MorphFlight<double>(
            source: source,
            destination: destination,
            kind: MorphFlightKind.routePush,
            curvedAnimation: const AlwaysStoppedAnimation(.5),
            uncurvedAnimation: animation,
            flightDelegate: delegate,
          );
          final before = flight.properties;
          if (changeStatus) {
            animation.reverse();
          } else {
            animation.value = .75;
          }
          final after = flight.properties;
          final cached = flight.properties;
          animation.stop();
          expect(
            (
              before,
              after,
              cached,
              delegate.interpolationCount,
              delegate.lastProgress!.uncurvedProgress,
              delegate.lastProgress!.animationStatus,
            ),
            (.5, .5, .5, 2, changeStatus ? .25 : .75, changeStatus ? AnimationStatus.reverse : AnimationStatus.forward),
          );
        },
      );
    }

    test(
      'when an endpoint transform is mutated, it should preserve the flight snapshot',
      () {
        final delegate = _CountingFlightDelegate();
        final flight = MorphFlight<double>(
          source: source,
          destination: destination,
          kind: MorphFlightKind.sameScreen,
          curvedAnimation: const AlwaysStoppedAnimation<double>(0.5),
          uncurvedAnimation: const AlwaysStoppedAnimation<double>(0.5),
          flightDelegate: delegate,
        );
        final first = flight.source;
        first.transform.storage[12] = 200;
        final second = flight.source;

        expect(
          (identical(first.transform, second.transform), second.transform.storage[12]),
          (false, 0),
        );
      },
    );

    for (final (curvedProgress, bounds) in [
      (0.25, const Rect.fromLTWH(20, 20, 60, 60)),
      (1.25, const Rect.fromLTWH(100, 100, 140, 140)),
    ]) {
      test('when curved progress is $curvedProgress, it should interpolate properties using that progress', () {
        final flight = MorphFlight<double>(
          source: source,
          destination: destination,
          kind: .sameScreen,
          curvedAnimation: AlwaysStoppedAnimation(curvedProgress),
          uncurvedAnimation: const AlwaysStoppedAnimation(0.5),
          flightDelegate: _CountingFlightDelegate(),
        );

        expect(flight.properties, curvedProgress);
      });

      test('when curved progress is $curvedProgress, it should interpolate bounds using that progress', () {
        final flight = MorphFlight<double>(
          source: source,
          destination: destination,
          kind: .sameScreen,
          curvedAnimation: AlwaysStoppedAnimation(curvedProgress),
          uncurvedAnimation: const AlwaysStoppedAnimation(0.5),
          flightDelegate: _CountingFlightDelegate(),
        );

        expect(flight.bounds, bounds);
      });
    }
  });
}
