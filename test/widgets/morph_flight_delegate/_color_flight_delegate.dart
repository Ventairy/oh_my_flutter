part of '../morph_flight_delegate_test.dart';

final class _ColorFlightDelegate extends MorphFlightDelegate<Color> {
  const _ColorFlightDelegate({this.onCapture, this.onBuild});

  final ValueChanged<Color>? onCapture;
  final void Function(MorphFlight<Color> flight)? onBuild;

  @override
  Color properties(MorphEndpointContext endpoint) {
    final color = (endpoint.child as ColoredBox).color;
    onCapture?.call(color);
    return color;
  }

  @override
  Color lerpProperties(Color source, Color destination, MorphFlightProgress progress) =>
      Color.lerp(source, destination, progress.curvedProgress)!;

  @override
  Widget buildFlight(BuildContext context, MorphFlight<Color> flight) {
    onBuild?.call(flight);
    return AnimatedBuilder(
      animation: flight.curvedAnimation,
      builder: (context, child) => ColoredBox(key: const ValueKey('custom-flight'), color: flight.properties),
    );
  }
}
