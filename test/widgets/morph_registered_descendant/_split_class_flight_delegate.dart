part of '../morph_registered_descendant_test.dart';

class _SplitClassFlightDelegate extends MorphFlightDelegate<_SplitFlightProperties> {
  const _SplitClassFlightDelegate();

  @override
  _SplitFlightProperties properties(MorphEndpointContext endpoint) {
    final row = (endpoint.child as SizedBox).child! as Row;
    return _SplitFlightProperties(
      first: endpoint.registerDescendantWidget((row.children.first as Expanded).child),
      second: endpoint.registerDescendantWidget((row.children.last as Expanded).child),
    );
  }

  @override
  _SplitFlightProperties lerpProperties(
    _SplitFlightProperties source,
    _SplitFlightProperties destination,
    double progress,
  ) {
    return _SplitFlightProperties(
      first: progress < 0.25 ? source.first : destination.first,
      second: progress < 0.75 ? source.second : destination.second,
    );
  }

  @override
  Widget buildFlight(BuildContext context, MorphFlight<_SplitFlightProperties> flight) {
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
