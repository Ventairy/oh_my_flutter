part of 'group.dart';

/// Connects independently placed widgets for operations on their combined content.
///
/// Keep one stable link and pass it to each [Group]. Members unregister when
/// detached; the link needs no disposal. Dispose snapshots you capture from it.
final class GroupLink {
  final Set<_RenderGroup> _members = <_RenderGroup>{};
  int _captureDepth = 0;
  final Set<GroupPresentationLease> _leases = {};

  void _attach(_RenderGroup member) {
    _members.add(member);
    for (final lease in _leases) {
      lease._attach(member);
    }
  }

  void _detach(_RenderGroup member) {
    _members.remove(member);
    for (final lease in _leases) {
      lease._detach(member);
    }
  }

  /// Measures the union of members in [relativeTo]'s local coordinates.
  ///
  /// Call after layout. Returns null when empty or unavailable. [relativeTo]
  /// must identify an attached render box in the same Flutter view as all members.
  Rect? measure({required BuildContext relativeTo}) {
    if (!relativeTo.mounted) return null;
    final reference = relativeTo.findRenderObject();
    if (reference is! RenderBox) return null;
    return _geometry(reference)?.bounds;
  }

  /// Captures the members together, independently of their original parents.
  ///
  /// Waits for the current frame when necessary. [bounds] is an optional output
  /// rectangle in [relativeTo]'s coordinates; otherwise the union is used.
  /// [pixelRatio] defaults to the view's device pixel ratio and must be positive.
  /// Returns null when empty, unavailable, or too large to capture safely.
  ///
  /// Captures child rendering and transforms, excluding ancestor clips and
  /// opacity. Put effects that should be included inside [Group]. Same-link
  /// nested members are included only through their outermost member.
  /// Dispose the returned snapshot when finished.
  Future<GroupSnapshot?> capture({
    required BuildContext relativeTo,
    Rect? bounds,
    double? pixelRatio,
  }) async {
    assert(pixelRatio == null || (pixelRatio.isFinite && pixelRatio > 0), 'pixelRatio must be positive and finite.');
    assert(bounds == null || (bounds.isFinite && !bounds.isEmpty), 'bounds must be finite and nonempty.');
    if (!relativeTo.mounted) return null;
    final ratio = pixelRatio ?? View.of(relativeTo).devicePixelRatio;
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase != SchedulerPhase.idle &&
        scheduler.schedulerPhase != SchedulerPhase.postFrameCallbacks) {
      await scheduler.endOfFrame;
    }
    if (!relativeTo.mounted) return null;
    final reference = relativeTo.findRenderObject();
    if (reference is! RenderBox) return null;
    return GroupCaptureAccess.capture(this, relativeTo: reference, bounds: bounds, pixelRatio: ratio);
  }

  ({Rect bounds, List<(_RenderGroup, Matrix4)> members})? _geometry(RenderBox reference) {
    if (!reference.attached || !reference.hasSize || _members.isEmpty) return null;
    RenderObject rootOf(RenderObject object) {
      var root = object;
      while (root.parent != null) {
        root = root.parent!;
      }
      return root;
    }

    final root = rootOf(reference);
    final inverse = Matrix4.tryInvert(reference.getTransformTo(null));
    if (inverse == null) return null;
    final members = <(_RenderGroup, Matrix4)>[];
    Rect? bounds;
    final order = _members.toList();
    final indices = {for (var i = 0; i < order.length; i++) order[i]: i};
    order.sort((a, b) {
      final z = a.zIndex.compareTo(b.zIndex);
      return z == 0 ? indices[a]!.compareTo(indices[b]!) : z;
    });
    for (final member in order) {
      if (!member.attached || !member.hasSize || !identical(rootOf(member), root)) return null;
      var nested = false;
      var ancestor = member.parent;
      while (ancestor != null) {
        if (ancestor is _RenderGroup && identical(ancestor.link, this)) {
          nested = true;
          break;
        }
        ancestor = ancestor.parent;
      }
      if (nested) continue;
      final transform = Matrix4.copy(inverse)..multiply(member.getTransformTo(null));
      final rect = MatrixUtils.transformRect(transform, member.paintBounds);
      if (!rect.isFinite) return null;
      members.add((member, transform));
      bounds = bounds?.expandToInclude(rect) ?? rect;
    }
    return bounds == null || bounds.isEmpty ? null : (bounds: bounds, members: members);
  }
}
