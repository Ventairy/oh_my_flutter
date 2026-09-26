part of 'morph.dart';

class _MorphOverlay extends StatefulWidget {
  const new(this.coordinator, this.entry);

  final _MorphCoordinator coordinator;
  final OverlayEntry entry;

  @override
  State<_MorphOverlay> createState() => _MorphOverlayState();
}

class _MorphOverlayState extends State<_MorphOverlay> {
  @override
  void dispose() {
    widget.coordinator.overlayUnmounted(widget.entry);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: widget.coordinator,
          builder: (context, child) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (final flight in widget.coordinator.flights) ...[
                  for (final node in widget.coordinator.nodesFor(flight, above: false))
                    _buildNode(context, node, flight),
                  KeyedSubtree(
                    key: ValueKey<Object>(flight.tag),
                    child: flight.build(context),
                  ),
                  for (final node in widget.coordinator.nodesFor(flight, above: true))
                    _buildNode(context, node, flight),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNode(BuildContext context, _MorphNodeHandle node, _MorphActiveFlight flight) {
    final projection = _MorphNodePaint(handle: node);
    final child =
        node.owner.widget.transitionBuilder?.call(
          context,
          projection,
          flight.morphAnimation,
          flight.flightAnimation,
        ) ??
        projection;
    return Positioned.fill(
      key: ObjectKey(node),
      child: CompositedTransformFollower(
        link: node.owner._layerLink,
        showWhenUnlinked: false,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(
            size: node.owner._renderObject!.size,
            child: ExcludeSemantics(child: child),
          ),
        ),
      ),
    );
  }
}
