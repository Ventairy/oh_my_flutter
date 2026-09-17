import 'package:flutter/widgets.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

part 'morph_benchmark_registered_flight_types.dart';

/// Selects registered descendant snapshots inside an interpolated surface.
final class RegisteredDelegate extends MorphFlightDelegate<FlightProperties> {
  /// Creates the registered-descendant benchmark delegate.
  const RegisteredDelegate();

  @override
  FlightProperties properties(
    MorphEndpointContext endpoint,
  ) {
    final container = endpoint.child as Container;
    return (
      decoration: container.decoration!,
      padding: container.padding! as EdgeInsets,
      child: endpoint.descendantWidget(container.child!),
    );
  }

  @override
  FlightProperties lerpProperties(
    FlightProperties source,
    FlightProperties destination,
    MorphFlightProgress progress,
  ) {
    return (
      decoration: Decoration.lerp(
        source.decoration,
        destination.decoration,
        progress.curvedProgress,
      )!,
      padding: EdgeInsets.lerp(
        source.padding,
        destination.padding,
        progress.curvedProgress,
      )!,
      child: progress.curvedProgress < 0.5 ? source.child : destination.child,
    );
  }

  @override
  Widget buildFlight(
    BuildContext context,
    MorphFlight<FlightProperties> flight,
  ) {
    return AnimatedBuilder(
      animation: flight.curvedAnimation,
      builder: (context, child) {
        final properties = flight.properties;
        return Container(
          decoration: properties.decoration,
          padding: properties.padding,
          child: properties.child,
        );
      },
    );
  }
}
