part of '../morph_candidate_test.dart';

final class _SnapshotCandidateDelegate extends MorphFlightDelegate<({MorphTarget target, Widget child})> {
  const new({this.onCapture, this.onFlight});

  final void Function(MorphTarget target)? onCapture;
  final void Function(MorphFlight<({MorphTarget target, Widget child})> flight)? onFlight;

  @override
  ({MorphTarget target, Widget child}) properties(MorphEndpointContext endpoint) {
    onCapture?.call(endpoint.target);
    return (
      target: endpoint.target,
      child: endpoint.descendantWidget(endpoint.child),
    );
  }

  @override
  ({MorphTarget target, Widget child}) lerpProperties(
    ({MorphTarget target, Widget child}) source,
    ({MorphTarget target, Widget child}) destination,
    MorphFlightProgress progress,
  ) => source;

  @override
  Widget buildFlight(
    BuildContext context,
    MorphFlight<({MorphTarget target, Widget child})> flight,
  ) {
    onFlight?.call(flight);
    return SizedBox.fromSize(
      size: flight.source.localSize,
      child: flight.source.properties.child,
    );
  }
}
