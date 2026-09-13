part of '../morph_endpoint_context_test.dart';

class _RegistrationDelegate extends MorphFlightDelegate<Widget> {
  const _RegistrationDelegate({required this.onRegister});

  final void Function(MorphEndpointContext endpoint, Widget registered) onRegister;

  @override
  Widget properties(MorphEndpointContext endpoint) {
    final registered = endpoint.registerDescendantWidget((endpoint.child as SizedBox).child!);
    onRegister(endpoint, registered);
    return registered;
  }

  @override
  Widget lerpProperties(Widget source, Widget destination, double progress) => progress < 0.5 ? source : destination;

  @override
  Widget buildFlight(BuildContext context, MorphFlight<Widget> flight) {
    return AnimatedBuilder(
      animation: flight.curvedAnimation,
      builder: (context, _) => flight.properties,
    );
  }
}
