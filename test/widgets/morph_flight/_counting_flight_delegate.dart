part of '../morph_flight_test.dart';

final class _CountingFlightDelegate extends MorphFlightDelegate<double> {
  int interpolationCount = 0;

  @override
  Widget buildFlight(BuildContext context, MorphFlight<double> flight) {
    return const SizedBox.shrink();
  }

  @override
  double lerpProperties(double source, double destination, double progress) {
    interpolationCount += 1;
    return source + (destination - source) * progress;
  }

  @override
  double properties(MorphEndpointContext endpoint) => 0;
}
