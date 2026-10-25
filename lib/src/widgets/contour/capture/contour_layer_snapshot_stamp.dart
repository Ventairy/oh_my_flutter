part of 'contour_layer_picture_snapshot.dart';

/// Detects source paint and layer changes before publishing a composite.
///
/// It keeps weak source identities and copies supported compositing values,
/// without retaining borrowed pictures after source freezing.
class ContourLayerSnapshotStamp {
  new _(
    ContainerLayer root,
    this.bounds,
    this.pixelRatio,
    this.generation,
    this._stamps,
  ) : _root = WeakReference<ContainerLayer>(root);

  /// The source capture rectangle.
  final ui.Rect bounds;

  /// Physical pixels per source pixel.
  final double pixelRatio;

  /// The caller's paint revision.
  final int generation;
  final WeakReference<ContainerLayer> _root;
  final List<_ContourLayerStamp> _stamps;
  bool _valid = true;

  /// Rejects all pending results when the source owner is detached or disposed.
  void invalidate() => _valid = false;

  /// Keeps an independent validity lease over the same immutable source values.
  ContourLayerSnapshotStamp? copy() {
    final root = _root.target;
    if (!_valid || root == null) return null;
    return ContourLayerSnapshotStamp._(root, bounds, pixelRatio, generation, _stamps);
  }

  /// Rechecks the exact source semantics, ignoring engineLayer bookkeeping.
  bool isCurrent({
    required ContainerLayer root,
    required ui.Rect bounds,
    required double pixelRatio,
    required int generation,
  }) {
    if (!_valid ||
        !identical(root, _root.target) ||
        this.bounds != bounds ||
        this.pixelRatio != pixelRatio ||
        this.generation != generation) {
      return false;
    }
    var index = 0;
    bool visit(ContainerLayer parent, int depth) {
      if (depth > 64) return false;
      for (var child = parent.firstChild; child != null; child = child.nextSibling) {
        if (index >= _stamps.length || !_stamps[index++].matches(child, depth)) return false;
        if (child is ContainerLayer && !visit(child, depth + 1)) {
          return false;
        }
      }
      return true;
    }

    return visit(root, 0) && index == _stamps.length;
  }
}
