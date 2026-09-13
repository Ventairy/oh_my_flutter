part of '../morph_barrier_handoff_test.dart';

final class _BarrierFlightDelegate extends MorphFlightDelegate<double> {
  @override
  double properties(MorphEndpointContext endpoint) => endpoint.localSize.width;

  @override
  double lerpProperties(double source, double destination, double progress) =>
      source + (destination - source) * progress;

  @override
  Widget buildFlight(BuildContext context, MorphFlight<double> flight) =>
      const ColoredBox(key: ValueKey('barrier-flight'), color: Colors.blue);
}
