part of '../morph_candidate_test.dart';

final class _CandidateDelegate extends MorphFlightDelegate<MorphTarget> {
  const new({this.onCapture, this.onFlight});

  final void Function(MorphTarget target)? onCapture;
  final void Function(MorphFlight<MorphTarget> flight)? onFlight;

  @override
  MorphTarget properties(MorphEndpointContext endpoint) {
    onCapture?.call(endpoint.target);
    return endpoint.target;
  }

  @override
  MorphTarget lerpProperties(MorphTarget source, MorphTarget destination, MorphFlightProgress progress) => source;

  @override
  Widget buildFlight(BuildContext context, MorphFlight<MorphTarget> flight) {
    onFlight?.call(flight);
    return const SizedBox.expand();
  }
}
