part of 'morph.dart';

class _MorphRegisteredDescendant extends StatefulWidget {
  _MorphRegisteredDescendant({required this.capture, required this.child, Widget? subtree})
    : subtree = subtree ?? child,
      super(key: UniqueKey());

  final _MorphDescendantCapture capture;
  final Widget child;
  final Widget subtree;

  _MorphRegisteredDescendant withChild(Widget child) {
    if (identical(child, this.child)) return this;
    return _MorphRegisteredDescendant(capture: capture, subtree: subtree, child: child);
  }

  @override
  State<_MorphRegisteredDescendant> createState() => _MorphRegisteredDescendantState();
}

class _MorphRegisteredDescendantState extends State<_MorphRegisteredDescendant> {
  _MorphDescendantFlightResolver? _resolver;

  @override
  Widget build(BuildContext context) {
    final flightScope = _MorphFlightScope.scopeOf(context);
    assert(
      flightScope != null && flightScope.registeredCaptures.contains(widget.capture),
      'Use the widget returned by descendantWidget in its associated '
      'Morph flight. It cannot be reused in an unrelated flight or outside a flight.',
    );
    return _MorphDescendantFlightScope(
      flightScope: flightScope,
      resolver: _resolver ??= _MorphDescendantFlightResolver(
        capture: widget.capture,
        subtree: widget.subtree,
      ),
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _resolver?.dispose();
    super.dispose();
  }
}
