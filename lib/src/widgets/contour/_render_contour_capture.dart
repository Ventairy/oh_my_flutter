part of 'contour.dart';

class _RenderContourCapture extends RenderRepaintBoundary {
  new(BuildContext context) : _coloredBoxSource = _ContourColoredBoxSource(context);

  final _ContourColoredBoxSource _coloredBoxSource;
  _ContourNativeTextCacheKey? _paintedTextKey;

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    _paintedTextKey = _ContourNativeText.paragraph(child) == null
        ? null
        : _ContourNativeTextCache.key(this, 1, paintBounds);
    final owner = parent;
    if (owner is _RenderContour) owner._sourcePainted();
  }

  @override
  void markNeedsPaint() {
    super.markNeedsPaint();
    final owner = parent;
    if (owner is _RenderContour) owner._sourceInvalidated();
  }

  @override
  OffsetLayer updateCompositedLayer({required _ContourLayer? oldLayer}) => oldLayer ?? _ContourLayer(_onComposition);

  void _onComposition() {
    final owner = parent;
    if (owner is _RenderContour) owner.sourceComposed();
  }

  bool get hasPendingContour {
    bool pending(RenderObject node) {
      if (node is _RenderContour && !node._initialReady) return true;
      var found = false;
      node.visitChildren((child) {
        if (!found && node.paintsChild(child)) found = pending(child);
      });
      return found;
    }

    return child != null && pending(child!);
  }

  @override
  Rect get paintBounds => child == null ? super.paintBounds : _subtreeBounds(child!);

  Rect _subtreeBounds(RenderObject root) {
    var bounds = root.paintBounds;
    if (root is RenderParagraph) {
      // Tight line heights can leave ascenders and descenders outside layout.
      final boxes = root.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: root.text.toPlainText(includeSemanticsLabels: false).length),
      );
      for (final box in boxes) {
        bounds = bounds.expandToInclude(box.toRect());
      }
    }
    root.visitChildren((child) {
      final transform = Matrix4.identity();
      root.applyPaintTransform(child, transform);
      var childBounds = MatrixUtils.transformRect(transform, _subtreeBounds(child));
      final clip = root.describeApproximatePaintClip(child);
      if (clip != null) childBounds = childBounds.intersect(clip);
      if (childBounds.isFinite && !childBounds.isEmpty) bounds = bounds.expandToInclude(childBounds);
    });
    return bounds;
  }

  _ContourLayer? get captureLayer => layer as _ContourLayer?;
}
