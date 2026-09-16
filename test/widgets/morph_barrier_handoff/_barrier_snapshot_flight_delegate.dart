part of '../morph_barrier_handoff_test.dart';

final class _BarrierSnapshotFlightDelegate extends MorphFlightDelegate<Widget> {
  const _BarrierSnapshotFlightDelegate();

  @override
  Widget properties(MorphEndpointContext endpoint) =>
      endpoint.registerDescendantWidget((endpoint.child as SizedBox).child!);

  @override
  Widget lerpProperties(Widget source, Widget destination, MorphFlightProgress progress) =>
      progress.curvedProgress < .5 ? source : destination;

  @override
  Widget buildFlight(BuildContext context, MorphFlight<Widget> flight) =>
      SizedBox.expand(key: const ValueKey('barrier-flight'), child: flight.properties);
}
