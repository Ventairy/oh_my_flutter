part of '../morph_group_test.dart';

final class _ConditionalWatchedGroupFlightDelegate extends MorphFlightDelegate<Widget> {
  const new({
    required this.group,
    required this.capturesGroup,
    required this.onCapture,
  });

  final GroupLink group;
  final bool capturesGroup;
  final VoidCallback onCapture;

  @override
  Iterable<GroupLink> get contentGroups => [group];

  @override
  Widget properties(MorphEndpointContext endpoint) {
    if (!capturesGroup) return const SizedBox.shrink();
    onCapture();
    return endpoint.groupSnapshot(group);
  }

  @override
  Widget lerpProperties(Widget source, Widget destination, MorphFlightProgress progress) => destination;

  @override
  Widget buildFlight(BuildContext context, MorphFlight<Widget> flight) {
    return AnimatedBuilder(
      animation: flight.curvedAnimation,
      builder: (context, child) => flight.properties,
    );
  }
}
