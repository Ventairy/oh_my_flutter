part of 'route_geometry_scene.dart';

final class _GeometryDelegate extends MorphFlightDelegate<Rect> {
  new(this.name);

  final String name;
  MorphFlight<Rect>? flight;

  @override
  Rect properties(MorphEndpointContext endpoint) => endpoint.overlayBounds;

  @override
  Rect lerpProperties(Rect source, Rect destination, MorphFlightProgress progress) =>
      Rect.lerp(source, destination, progress.curvedProgress)!;

  @override
  Widget buildFlight(BuildContext context, MorphFlight<Rect> flight) {
    this.flight = flight;
    return ColoredBox(key: ValueKey('flight_$name'), color: name == 'surface' ? const Color(0xFFE0E7FF) : Colors.blue);
  }
}
