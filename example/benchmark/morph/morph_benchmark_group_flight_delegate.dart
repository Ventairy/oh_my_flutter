import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Custom delegate matching a full-surface grouped-content flight.
final class MorphBenchmarkGroupFlightDelegate extends MorphFlightDelegate<({Size size, Widget snapshot})> {
  /// Creates a delegate that captures [link] within each endpoint.
  const new(this.link);

  /// Group whose content is captured for this endpoint.
  final GroupLink link;

  @override
  Iterable<GroupLink> get contentGroups => [link];

  @override
  ({Size size, Widget snapshot}) properties(MorphEndpointContext endpoint) {
    return (size: endpoint.localSize, snapshot: endpoint.groupSnapshot(link));
  }

  @override
  ({Size size, Widget snapshot}) lerpProperties(
    ({Size size, Widget snapshot}) source,
    ({Size size, Widget snapshot}) destination,
    MorphFlightProgress progress,
  ) {
    return (
      size: Size.lerp(source.size, destination.size, progress.curvedProgress)!,
      snapshot: progress.curvedProgress < .5 ? source.snapshot : destination.snapshot,
    );
  }

  @override
  Widget buildFlight(BuildContext context, MorphFlight<({Size size, Widget snapshot})> flight) {
    return AnimatedBuilder(
      animation: flight.curvedAnimation,
      builder: (context, child) {
        final properties = flight.properties;
        return SizedBox.fromSize(
          size: properties.size,
          child: FittedBox(fit: BoxFit.fill, child: properties.snapshot),
        );
      },
    );
  }
}
