part of '../morph_flight_delegate_test.dart';

final class _IndependentFlightDelegate extends MorphFlightDelegate<double> {
  final List<MorphFlight<double>> flights = [];
  MorphFlightProgress? progress;

  @override
  double properties(MorphEndpointContext endpoint) => endpoint.localSize.width;

  @override
  double lerpProperties(double source, double destination, MorphFlightProgress progress) {
    this.progress = progress;
    return source + (destination - source) * progress.uncurvedProgress;
  }

  @override
  Widget buildFlight(BuildContext context, MorphFlight<double> flight) {
    flights.add(flight);
    return AnimatedBuilder(
      animation: flight.uncurvedAnimation,
      builder: (context, child) => Opacity(
        opacity: (flight.properties / 400).clamp(0, 1),
        child: const ColoredBox(color: Colors.blue),
      ),
    );
  }
}
