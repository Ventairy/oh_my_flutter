part of 'snap_list.dart';

class _RenderSnapListTrailingSliver extends RenderSliverToBoxAdapter {
  new({required this._viewportOffset, required this._paintOutsideViewport});

  ViewportOffset _viewportOffset;
  bool _paintOutsideViewport;

  void configure({required ViewportOffset viewportOffset, required bool paintOutsideViewport}) {
    if (identical(_viewportOffset, viewportOffset) && _paintOutsideViewport == paintOutsideViewport) return;
    if (attached) _viewportOffset.removeListener(markNeedsLayout);
    _viewportOffset = viewportOffset;
    _paintOutsideViewport = paintOutsideViewport;
    if (attached) _viewportOffset.addListener(markNeedsLayout);
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _viewportOffset.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _viewportOffset.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    // An unclipped child can already be on screen before its sliver intersects
    // the viewport. Keep painting it there instead of switching it on mid-entry.
    if (_paintOutsideViewport && child != null && !geometry!.visible) {
      final double distanceBeyondViewport = math.max(
        0,
        constraints.precedingScrollExtent - _viewportOffset.pixels - constraints.viewportMainAxisExtent,
      );
      // Visible slivers are positioned at the end of the preceding paint area.
      // Retain the remaining scroll distance when painting beyond that area.
      (child!.parentData! as SliverPhysicalParentData).paintOffset += switch (constraints.axisDirection) {
        AxisDirection.down => Offset(0, distanceBeyondViewport),
        AxisDirection.up => Offset(0, -distanceBeyondViewport),
        AxisDirection.right => Offset(distanceBeyondViewport, 0),
        AxisDirection.left => Offset(-distanceBeyondViewport, 0),
      };
      geometry = geometry!.copyWith(visible: true);
    }
  }

  @override
  Rect? describeSemanticsClip(RenderBox? child) {
    if (!_paintOutsideViewport) return null;
    final paintOffset = (parentData! as SliverPhysicalParentData).paintOffset;
    final viewportSize = switch (constraints.axis) {
      Axis.vertical => Size(constraints.crossAxisExtent, constraints.viewportMainAxisExtent),
      Axis.horizontal => Size(constraints.viewportMainAxisExtent, constraints.crossAxisExtent),
    };
    return Offset(-paintOffset.dx, -paintOffset.dy) & viewportSize;
  }
}
