part of 'morph.dart';

class _MorphAutomaticFlight extends StatefulWidget {
  const _MorphAutomaticFlight({
    required this.flight,
    required this.switchThreshold,
    required this.transitionBuilder,
  });

  final MorphFlight<_MorphAutomaticProperties> flight;
  final double switchThreshold;
  final AnimatedSwitcherTransitionBuilder? transitionBuilder;

  @override
  State<_MorphAutomaticFlight> createState() => _MorphAutomaticFlightState();
}

class _MorphAutomaticFlightState extends State<_MorphAutomaticFlight> {
  late bool _showsSource;

  @override
  void initState() {
    super.initState();
    _showsSource = _sourceIsSelected;
    widget.flight.animation.addListener(_handleProgressChanged);
  }

  @override
  void didUpdateWidget(_MorphAutomaticFlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.flight.animation, widget.flight.animation)) {
      oldWidget.flight.animation.removeListener(_handleProgressChanged);
      widget.flight.animation.addListener(_handleProgressChanged);
    }
    _showsSource = _sourceIsSelected;
  }

  @override
  void dispose() {
    widget.flight.animation.removeListener(_handleProgressChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.flight.animation.value;
    final selected = _showsSource ? widget.flight._sourceProperties.child : widget.flight._destinationProperties.child;
    final transitionBuilder = widget.transitionBuilder;
    final properties = transitionBuilder == null
        ? selected
        : _showsSource
        ? MorphChildFlightDelegate._departing(
            properties: selected,
            progress: progress,
            threshold: widget.switchThreshold,
            transitionEnabled: true,
          )
        : MorphChildFlightDelegate._arriving(
            properties: selected,
            progress: progress,
            threshold: widget.switchThreshold,
            transitionEnabled: true,
          );
    return MorphChildFlightDelegate.build(
      context,
      properties,
      switchTransition: transitionBuilder,
    );
  }

  bool get _sourceIsSelected {
    return widget.flight.animation.value < widget.switchThreshold;
  }

  void _handleProgressChanged() {
    final showsSource = _sourceIsSelected;
    if (showsSource == _showsSource && widget.transitionBuilder == null) {
      return;
    }
    setState(() => _showsSource = showsSource);
  }
}
