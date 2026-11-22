part of 'morph.dart';

class _RenderMorphDepartureBridge extends RenderProxyBox {
  new(this.coordinator);

  final _MorphCoordinator coordinator;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    coordinator._departureRepaint.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    coordinator._departureRepaint.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final painted = <_MorphEndpointHandle>{};
    for (final incoming in coordinator._scheduledIncomingEndpoints) {
      final target = incoming.preparedTarget;
      if (target == null || !incoming.active) continue;
      final source = coordinator._sourceForMatch(incoming, target);
      if (source == null || source.active || !identical(source.route, incoming.route) || !painted.add(source)) continue;
      final departure = coordinator._departures[source];
      final layer = departure?.layer.layer;
      if (departure == null || layer == null) continue;
      context.pushTransform(true, offset, departure.transform, (context, offset) {
        layer.offset = offset;
        context.addLayer(layer);
      });
    }
    super.paint(context, offset);
  }
}
