part of '../morph_registered_descendant_test.dart';

class _SnapshotFlightDelegate extends MorphFlightDelegate<Widget> {
  const _SnapshotFlightDelegate({
    this.switchAt = 0.8,
    this.register = true,
    this.usesUncurvedAnimation = false,
    this.crossFade = false,
  });

  final double switchAt;
  final bool register;
  final bool usesUncurvedAnimation;
  final bool crossFade;

  @override
  Widget properties(MorphEndpointContext endpoint) {
    final child = (endpoint.child as SizedBox).child!;
    return register ? endpoint.registerDescendantWidget(child) : child;
  }

  @override
  Widget lerpProperties(Widget source, Widget destination, double progress) {
    return progress < switchAt ? source : destination;
  }

  @override
  Widget buildFlight(BuildContext context, MorphFlight<Widget> flight) {
    if (crossFade) {
      return Row(
        children: [
          Expanded(
            child: ClipRect(
              child: Center(
                child: FadeTransition(
                  opacity: ReverseAnimation(flight.uncurvedAnimation),
                  child: flight.source.properties,
                ),
              ),
            ),
          ),
          Expanded(
            child: ClipRect(
              child: Center(
                child: FadeTransition(
                  opacity: flight.uncurvedAnimation,
                  child: flight.destination.properties,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return AnimatedBuilder(
      animation: usesUncurvedAnimation ? flight.uncurvedAnimation : flight.curvedAnimation,
      builder: (context, _) => Center(
        child: usesUncurvedAnimation
            ? flight.uncurvedAnimation.value < switchAt
                  ? flight.source.properties
                  : flight.destination.properties
            : flight.properties,
      ),
    );
  }
}
