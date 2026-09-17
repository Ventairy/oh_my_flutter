part of '../morph_registered_descendant_test.dart';

class _SplitFlightDelegate extends MorphFlightDelegate<_SplitProperties> {
  const _SplitFlightDelegate();

  @override
  _SplitProperties properties(MorphEndpointContext endpoint) {
    final row = (endpoint.child as SizedBox).child! as Row;
    return (
      first: endpoint.descendantWidget((row.children.first as Expanded).child),
      second: endpoint.descendantWidget((row.children.last as Expanded).child),
    );
  }

  @override
  _SplitProperties lerpProperties(_SplitProperties source, _SplitProperties destination, MorphFlightProgress progress) {
    return (
      first: progress.curvedProgress < 0.25 ? source.first : destination.first,
      second: progress.curvedProgress < 0.75 ? source.second : destination.second,
    );
  }

  @override
  Widget buildFlight(BuildContext context, MorphFlight<_SplitProperties> flight) {
    return AnimatedBuilder(
      animation: flight.curvedAnimation,
      builder: (context, _) => Row(
        children: [
          Expanded(
            child: ClipRect(child: Center(child: flight.properties.first)),
          ),
          Expanded(
            child: ClipRect(child: Center(child: flight.properties.second)),
          ),
        ],
      ),
    );
  }
}
