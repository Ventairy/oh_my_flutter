part of 'snap_list.dart';

class _RenderSnapListEagerContent extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _SnapListParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _SnapListParentData> {
  _RenderSnapListEagerContent(this.motion, this.direction, this.extent, this.leading);
  final _SnapListMotion motion;
  AxisDirection direction;
  double extent;
  double leading;
  final List<RenderBox> _children = [];

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    motion.addListener(markNeedsSemanticsUpdate);
  }

  @override
  void detach() {
    motion.removeListener(markNeedsSemanticsUpdate);
    super.detach();
  }

  void configure(AxisDirection value, double viewportExtent, double anchor) {
    direction = value;
    extent = viewportExtent;
    leading = anchor;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _SnapListParentData) child.parentData = _SnapListParentData();
  }

  @override
  void performLayout() {
    final vertical = axisDirectionToAxis(direction) == Axis.vertical;
    final total = childCount * motion.stride;
    size = constraints.constrain(vertical ? Size(constraints.maxWidth, total) : Size(total, constraints.maxHeight));
    final childConstraints = BoxConstraints.tight(
      vertical ? Size(size.width, motion.stride) : Size(motion.stride, size.height),
    );
    _children.clear();
    var child = firstChild;
    var index = 0;
    while (child != null) {
      child.layout(childConstraints);
      final data = child.parentData! as _SnapListParentData;
      final offset = axisDirectionIsReversed(direction) ? total - (index + 1) * motion.stride : index * motion.stride;
      data.offset = vertical ? Offset(0, offset) : Offset(offset, 0);
      _children.add(child);
      child = data.nextSibling;
      index++;
    }
  }

  (int, int) get _range {
    final pixels = motion.displayPixels;
    return (
      math.max(0, ((pixels - leading) / motion.stride).floor()),
      math.min(_children.length - 1, ((pixels + extent - leading) / motion.stride).floor()),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final range = _range;
    for (var i = range.$1; i <= range.$2; i++) {
      final child = _children[i];
      context.paintChild(child, offset + (child.parentData! as _SnapListParentData).offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final range = _range;
    for (var i = range.$2; i >= range.$1; i--) {
      final child = _children[i];
      if (result.addWithPaintOffset(
        offset: (child.parentData! as _SnapListParentData).offset,
        position: position,
        hitTest: (result, point) => child.hitTest(result, position: point),
      )) {
        return true;
      }
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final range = _range;
    for (var i = range.$1; i <= range.$2; i++) {
      visitor(_children[i]);
    }
  }
}
