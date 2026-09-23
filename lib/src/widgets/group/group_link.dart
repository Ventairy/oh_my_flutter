part of 'group.dart';

/// Connects independently placed widgets for operations on their combined content.
///
/// Keep one stable link and pass it to each [Group]. Members unregister when
/// detached; the link needs no disposal. Dispose snapshots you capture from it.
final class GroupLink {
  final Set<_RenderGroup> _members = <_RenderGroup>{};
  List<_RenderGroup>? _membersInPaintOrder;
  int _captureDepth = 0;
  final Set<GroupPresentationLease> _leases = {};

  void _attach(_RenderGroup member) {
    _members.add(member);
    _membersInPaintOrder = null;
    for (final lease in _leases) {
      lease._attach(member);
    }
  }

  void _detach(_RenderGroup member) {
    _members.remove(member);
    _membersInPaintOrder = null;
    for (final lease in _leases) {
      lease._detach(member);
    }
  }

  void _invalidateMemberOrder() => _membersInPaintOrder = null;

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
    final memberTransform = Matrix4.identity();
    final edgeTransform = Matrix4.identity();
    Matrix4? referenceInverse;
    RenderObject? referenceRoot;
    final members = <(_RenderGroup, Matrix4)>[];
    Rect? bounds;
    for (final member in _orderedMembers) {
      if (!member.attached || !member.hasSize || !identical(member.owner, reference.owner)) return null;
      final memberRoot = _writeTransformToReferenceOrRoot(
        member,
        reference: reference,
        transform: memberTransform,
        edgeTransform: edgeTransform,
      );
      if (memberRoot != null) {
        var inverse = referenceInverse;
        if (inverse == null) {
          inverse = Matrix4.identity();
          referenceRoot = _writeTransformToRoot(
            reference,
            transform: inverse,
            edgeTransform: edgeTransform,
          );
          if (inverse.invert() == 0) return null;
          referenceInverse = inverse;
        }
        if (!identical(memberRoot, referenceRoot)) return null;
        memberTransform.leftMultiply(inverse);
      }
      if (_isNestedMember(member)) continue;
      final rect = MatrixUtils.transformRect(memberTransform, member.paintBounds);
      if (!rect.isFinite) return null;
      members.add((member, Matrix4.copy(memberTransform)));
      bounds = bounds?.expandToInclude(rect) ?? rect;
    }
    return bounds == null || bounds.isEmpty ? null : (bounds: bounds, members: members);
  }

  int? _revision(RenderBox reference) {
    if (!reference.attached || !reference.hasSize || _members.isEmpty) return null;
    final memberTransform = Matrix4.identity();
    final edgeTransform = Matrix4.identity();
    Matrix4? referenceInverse;
    RenderObject? referenceRoot;
    var hasBounds = false;
    var revision = 0;
    for (final member in _orderedMembers) {
      if (!member.attached || !member.hasSize || !identical(member.owner, reference.owner)) return null;
      final memberRoot = _writeTransformToReferenceOrRoot(
        member,
        reference: reference,
        transform: memberTransform,
        edgeTransform: edgeTransform,
      );
      if (memberRoot != null) {
        var inverse = referenceInverse;
        if (inverse == null) {
          inverse = Matrix4.identity();
          referenceRoot = _writeTransformToRoot(
            reference,
            transform: inverse,
            edgeTransform: edgeTransform,
          );
          if (inverse.invert() == 0) return null;
          referenceInverse = inverse;
        }
        if (!identical(memberRoot, referenceRoot)) return null;
        memberTransform.leftMultiply(inverse);
      }
      if (_isNestedMember(member)) continue;
      final rect = MatrixUtils.transformRect(memberTransform, member.paintBounds);
      if (!rect.isFinite) return null;
      hasBounds = hasBounds || !rect.isEmpty;
      revision = Object.hash(
        revision,
        member,
        member._revision,
        member.size,
        member.zIndex,
        Object.hashAll(memberTransform.storage),
      );
    }
    return hasBounds ? revision : null;
  }

  List<_RenderGroup> get _orderedMembers {
    final cachedMembers = _membersInPaintOrder;
    if (cachedMembers != null) return cachedMembers;
    final members = _members.toList(growable: false);
    final registrationIndices = {for (var index = 0; index < members.length; index++) members[index]: index};
    members.sort((first, second) {
      final zIndexOrder = first.zIndex.compareTo(second.zIndex);
      return zIndexOrder == 0 ? registrationIndices[first]!.compareTo(registrationIndices[second]!) : zIndexOrder;
    });
    return _membersInPaintOrder = members;
  }

  RenderObject _writeTransformToRoot(
    RenderObject object, {
    required Matrix4 transform,
    required Matrix4 edgeTransform,
  }) {
    assert(object.attached, 'Group transforms require attached render objects.');
    transform.setIdentity();
    var child = object;
    while (true) {
      final parent = child.parent;
      if (parent == null) return child;
      // Match getTransformTo(null), which excludes the root node's transform.
      if (parent.parent == null) return parent;
      edgeTransform.setIdentity();
      parent.applyPaintTransform(child, edgeTransform);
      transform.leftMultiply(edgeTransform);
      child = parent;
    }
  }

  RenderObject? _writeTransformToReferenceOrRoot(
    RenderObject object, {
    required RenderObject reference,
    required Matrix4 transform,
    required Matrix4 edgeTransform,
  }) {
    assert(object.attached, 'Group transforms require attached render objects.');
    transform.setIdentity();
    var child = object;
    while (!identical(child, reference)) {
      final parent = child.parent;
      if (parent == null) return child;
      // Keep cross-branch transforms in the same root coordinate space as
      // getTransformTo(null), which excludes the root node's transform.
      if (parent.parent == null && !identical(parent, reference)) return parent;
      edgeTransform.setIdentity();
      parent.applyPaintTransform(child, edgeTransform);
      transform.leftMultiply(edgeTransform);
      child = parent;
    }
    return null;
  }

  bool _isNestedMember(_RenderGroup member) {
    var ancestor = member.parent;
    while (ancestor != null) {
      if (ancestor is _RenderGroup && identical(ancestor.link, this)) return true;
      ancestor = ancestor.parent;
    }
    return false;
  }
}
