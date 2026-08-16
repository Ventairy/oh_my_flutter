part of 'morph.dart';

final class _MorphDescendantHandle {
  _MorphDescendantHandle({required this.owner});

  final _MorphDescendantState owner;
  _RenderMorphDescendant? renderObject;
  int registrationOrder = 0;

  _RenderMorphDescendant? get capturableRenderObject {
    final renderObject = this.renderObject;
    if (renderObject == null || !renderObject.attached || !renderObject.hasSize) {
      return null;
    }
    return renderObject;
  }

  _MorphDescendantFlightRecord capture(_RenderMorphDescendant renderObject) {
    final widget = owner.widget;
    final behavior = widget.flightBehavior;
    return _MorphDescendantFlightRecord(
      registrationOrder: registrationOrder,
      key: widget.key,
      childType: widget.child.runtimeType,
      behavior: behavior,
      size: renderObject.size,
      snapshot: null,
    );
  }
}
