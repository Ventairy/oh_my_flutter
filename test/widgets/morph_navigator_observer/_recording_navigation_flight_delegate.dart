part of '../morph_navigator_observer_test.dart';

final class _RecordingNavigationFlightDelegate extends MorphFlightDelegate<double> {
  _RecordingNavigationFlightDelegate(this.flights);

  final List<MorphFlight<double>> flights;

  @override
  double properties(MorphEndpointContext endpoint) => endpoint.localSize.width;

  @override
  double lerpProperties(double source, double destination, MorphFlightProgress progress) =>
      source + (destination - source) * progress.curvedProgress;

  @override
  Widget buildFlight(BuildContext context, MorphFlight<double> flight) {
    flights.add(flight);
    return const ColoredBox(color: Colors.blue);
  }
}
