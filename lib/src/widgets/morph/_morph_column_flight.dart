part of 'morph.dart';

class _MorphColumnFlight extends StatefulWidget {
  const _MorphColumnFlight({
    required this.delegate,
    required this.flight,
    required this.switchTransition,
  });

  final MorphColumnFlightDelegate delegate;
  final MorphFlight<MorphColumnProperties> flight;
  final AnimatedSwitcherTransitionBuilder? switchTransition;

  @override
  State<_MorphColumnFlight> createState() => _MorphColumnFlightState();
}

class _MorphColumnFlightState extends State<_MorphColumnFlight> {
  late _MorphColumnFlightPlan _plan;

  @override
  void initState() {
    super.initState();
    _plan = _createPlan();
  }

  @override
  void didUpdateWidget(_MorphColumnFlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(
          oldWidget.flight.source.properties,
          widget.flight.source.properties,
        ) &&
        identical(
          oldWidget.flight.destination.properties,
          widget.flight.destination.properties,
        )) {
      return;
    }
    _plan = _createPlan();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.flight.animation,
      builder: (context, child) {
        return widget.delegate._buildProperties(
          context,
          _plan.lerp(widget.flight.animation.value),
          switchTransition: widget.switchTransition,
        );
      },
    );
  }

  _MorphColumnFlightPlan _createPlan() {
    return _MorphColumnFlightPlan(
      source: widget.flight.source.properties,
      destination: widget.flight.destination.properties,
      transitionEnabled: widget.switchTransition != null,
    );
  }
}
