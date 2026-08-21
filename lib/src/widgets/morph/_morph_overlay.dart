part of 'morph.dart';

class _MorphOverlay extends StatefulWidget {
  const _MorphOverlay(this.coordinator, this.entry);

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
                for (final flight in widget.coordinator.flights)
                  KeyedSubtree(
                    key: ValueKey<Object>(flight.tag),
                    child: flight.build(context),
                  ),
                for (final foreground in widget.coordinator.foregrounds) foreground.overlayProjection,
              ],
            );
          },
        ),
      ),
    );
  }
}
