// dart format width=80
part of '../group_morph_example.dart';

class _GroupMorphDelegate extends MorphFlightDelegate<Widget> {
  const new(this.link);
  final GroupLink link;

  @override
  Widget properties(MorphEndpointContext endpoint) =>
      endpoint.groupSnapshot(link);

  @override
  Widget lerpProperties(
    Widget source,
    Widget destination,
    MorphFlightProgress progress,
  ) => progress.curvedProgress < .5 ? source : destination;

  @override
  Widget buildFlight(BuildContext context, MorphFlight<Widget> flight) => Stack(
    fit: StackFit.expand,
    children: [
      FadeTransition(
        opacity: ReverseAnimation(flight.uncurvedAnimation),
        child: FittedBox(fit: BoxFit.fill, child: flight.source.properties),
      ),
      FadeTransition(
        opacity: flight.uncurvedAnimation,
        child: FittedBox(
          fit: BoxFit.fill,
          child: flight.destination.properties,
        ),
      ),
    ],
  );
}
