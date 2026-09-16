part of 'snap_list.dart';

class _SnapListEagerContent extends MultiChildRenderObjectWidget {
  const _SnapListEagerContent({
    required this.motion,
    required this.direction,
    required this.extent,
    required this.leading,
    required super.children,
  });
  final _SnapListMotion motion;
  final AxisDirection direction;
  final double extent;
  final double leading;

  @override
  _RenderSnapListEagerContent createRenderObject(BuildContext context) =>
      _RenderSnapListEagerContent(motion, direction, extent, leading);

  @override
  void updateRenderObject(BuildContext context, _RenderSnapListEagerContent renderObject) =>
      renderObject.configure(direction, extent, leading);
}
