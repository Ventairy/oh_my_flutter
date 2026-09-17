part of '../morph_group_test.dart';

class _GroupFlightDelegate extends MorphFlightDelegate<Widget> {
  const _GroupFlightDelegate(this.link);
  final GroupLink link;

  @override
  Widget properties(MorphEndpointContext endpoint) => endpoint.groupSnapshot(link);

  @override
  Widget lerpProperties(Widget source, Widget destination, MorphFlightProgress progress) => destination;

  @override
  Widget buildFlight(BuildContext context, MorphFlight<Widget> flight) =>
      Stack(children: [flight.source.properties, flight.destination.properties]);
}
