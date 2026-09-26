part of 'snap_list.dart';

class _SnapListTrailingSliver extends SingleChildRenderObjectWidget {
  const new({required this.viewportOffset, required this.paintOutsideViewport, required super.child});

  final ViewportOffset viewportOffset;
  final bool paintOutsideViewport;

  @override
  _RenderSnapListTrailingSliver createRenderObject(BuildContext context) =>
      _RenderSnapListTrailingSliver(viewportOffset: viewportOffset, paintOutsideViewport: paintOutsideViewport);

  @override
  void updateRenderObject(BuildContext context, _RenderSnapListTrailingSliver renderObject) =>
      renderObject.configure(viewportOffset: viewportOffset, paintOutsideViewport: paintOutsideViewport);
}
