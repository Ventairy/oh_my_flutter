part of 'snap_list.dart';

class _SnapListTrailing extends SingleChildRenderObjectWidget {
  const new({
    required this.axis,
    required this.extent,
    required this.onExtentChanged,
    required super.child,
  });

  final Axis axis;
  final double extent;
  final ValueChanged<double> onExtentChanged;

  @override
  _RenderSnapListTrailing createRenderObject(BuildContext context) =>
      _RenderSnapListTrailing(axis, extent, onExtentChanged);

  @override
  void updateRenderObject(BuildContext context, _RenderSnapListTrailing renderObject) =>
      renderObject.configure(axis, extent, onExtentChanged);
}
