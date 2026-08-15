import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

final class _CountingFlightDelegate extends MorphFlightDelegate<double> {
  _CountingFlightDelegate();

  int interpolationCount = 0;

  @override
  Widget buildFlight(BuildContext context, MorphFlight<double> flight) {
    return const SizedBox.shrink();
  }

  @override
  double lerp(double source, double destination, double progress) {
    interpolationCount += 1;
    return source + (destination - source) * progress;
  }

  @override
  double properties(MorphEndpointContext endpoint) => 0;
}

MorphEndpoint<double> _endpoint(double properties) {
  return MorphEndpoint<double>(
    properties: properties,
    bounds: Rect.zero,
    localSize: Size.zero,
    transform: Matrix4.identity(),
    axisScale: const Offset(1, 1),
  );
}

void main() {
  group('MorphFlight', () {
    test(
      'when properties is read repeatedly at one progress, it should interpolate once',
      () {
        final delegate = _CountingFlightDelegate();
        final flight = MorphFlight<double>(
          source: _endpoint(0),
          destination: _endpoint(1),
          kind: MorphFlightKind.sameScreen,
          animation: const AlwaysStoppedAnimation<double>(0.5),
          flightDelegate: delegate,
        );

        final values = (flight.properties, flight.properties);

        expect((values, delegate.interpolationCount), ((0.5, 0.5), 1));
      },
    );

    test(
      'when an endpoint transform is mutated, it should preserve the flight snapshot',
      () {
        final delegate = _CountingFlightDelegate();
        final flight = MorphFlight<double>(
          source: _endpoint(0),
          destination: _endpoint(1),
          kind: MorphFlightKind.sameScreen,
          animation: const AlwaysStoppedAnimation<double>(0.5),
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
  });
}
