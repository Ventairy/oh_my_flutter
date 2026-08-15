import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Minimal custom delegate used to isolate Morph's generic watched-flight path.
final class BenchmarkCustomFlightDelegate extends MorphFlightDelegate<Color> {
  /// Creates the benchmark delegate.
  const BenchmarkCustomFlightDelegate();

  @override
  Color properties(MorphEndpointContext endpoint) {
    final child = endpoint.child;
    if (child is! ColoredBox) {
      throw ArgumentError.value(
        child,
        'endpoint.child',
        'BenchmarkCustomFlightDelegate requires a ColoredBox child.',
      );
    }
    return child.color;
  }

  @override
  Color lerp(Color source, Color destination, double progress) {
    return Color.lerp(source, destination, progress)!;
  }

  @override
  Widget buildFlight(
    BuildContext context,
    MorphFlight<Color> flight,
  ) {
    return AnimatedBuilder(
      animation: flight.animation,
      builder: (context, child) => ColoredBox(color: flight.properties),
    );
  }
}
