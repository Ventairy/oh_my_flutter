part of '../morph_flight_test.dart';

final class _CountingFlightDelegate extends MorphFlightDelegate<double> {
  int interpolationCount = 0;
  MorphFlightProgress? lastProgress;

  @override
  Widget buildFlight(BuildContext context, MorphFlight<double> flight) {
    return const SizedBox.shrink();
  }

  @override
  double lerpProperties(double source, double destination, MorphFlightProgress progress) {
    interpolationCount += 1;
    lastProgress = progress;
    return source + (destination - source) * progress.curvedProgress;
  }

  @override
  double properties(MorphEndpointContext endpoint) => 0;
}
