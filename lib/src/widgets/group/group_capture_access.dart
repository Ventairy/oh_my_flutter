part of 'group.dart';

/// Package-internal synchronous capture bridge for presentation consumers.
@internal
final class GroupCaptureAccess {
  /// Captures an already laid-out group without delaying a presentation frame.
  static GroupSnapshot? capture(
    GroupLink link, {
    required RenderBox relativeTo,
    required double pixelRatio,
    Rect? bounds,
    VoidCallback Function(Iterable<RenderObject> members)? prepare,
  }) => captureWithRevision(
    link,
    relativeTo: relativeTo,
    pixelRatio: pixelRatio,
    bounds: bounds,
    prepare: prepare,
  )?.snapshot;

  /// Captures a group and returns the revision represented by the snapshot.
  static ({GroupSnapshot snapshot, int revision})? captureWithRevision(
    GroupLink link, {
    required RenderBox relativeTo,
    required double pixelRatio,
    Rect? bounds,
    VoidCallback Function(Iterable<RenderObject> members)? prepare,
  }) {
    final geometry = link._geometry(relativeTo);
    if (geometry == null) return null;
    final output = bounds ?? geometry.bounds;
    if (!output.isFinite || output.isEmpty) return null;
    final pixels = (output.width * pixelRatio).ceil() * (output.height * pixelRatio).ceil();
    if (pixels > RasterSnapshot.maximumCapturePhysicalPixels) return null;
    final before = _revisionOf(geometry.members);
    final layer = OffsetLayer();
    link._captureDepth++;
    VoidCallback? restore;
    try {
      restore = prepare?.call(geometry.members.map((entry) => entry.$1));
      FlutterErrorDetails? paintError;
      final previousOnError = FlutterError.onError;
      final context = PaintingContext(layer, Offset.zero & output.size);
      try {
        FlutterError.onError = (details) => paintError ??= details;
        context
          ..pushClipRect(true, Offset.zero, Offset.zero & output.size, (context, offset) {
            for (final (member, transform) in geometry.members) {
              if (member.size.isEmpty) continue;
              final placement = Matrix4.translationValues(-output.left, -output.top, 0)..multiply(transform);
              context.pushTransform(member.needsCompositing, offset, placement, member.paint);
            }
          })
          // Finish the offscreen render operation before rasterization.
          // ignore: invalid_use_of_protected_member
          ..stopRecordingIfNeeded();
      } finally {
        FlutterError.onError = previousOnError;
      }
      final after = link._revision(relativeTo);
      if (paintError != null || !layer.supportsRasterization() || after == null || before != after) {
        return null;
      }
      final snapshot = RasterSnapshot.tiled(layer: layer, size: output.size, pixelRatio: pixelRatio);
      return (
        snapshot: GroupSnapshot._(output, snapshot, pixelRatio),
        revision: before,
      );
    } finally {
      restore?.call();
      link._captureDepth--;
      for (final (member, _) in geometry.members) {
        // Offscreen painting can temporarily reparent descendant layers.
        if (member.needsCompositing) member.restoreAfterCapture();
      }
      layer.dispose();
    }
  }

  /// Identifies the current geometry and painted content for cache validation.
  static int? revision(GroupLink link, RenderBox reference) => link._revision(reference);

  static int _revisionOf(List<(_RenderGroup, Matrix4)> members) {
    var revision = 0;
    for (final (member, transform) in members) {
      revision = Object.hash(
        revision,
        member,
        member._revision,
        member.size,
        member.zIndex,
        Object.hashAll(transform.storage),
      );
    }
    return revision;
  }

  /// Temporarily suppresses the registered originals without changing layout.
  static GroupPresentationLease hide(GroupLink link) => GroupPresentationLease._(link);

  /// Paints suppressed group members only for the duration of [paint].
  static T paintSuppressed<T>(Iterable<GroupLink> links, T Function() paint) {
    final uniqueLinks = links is Set<GroupLink> ? links : (Set<GroupLink>.identity()..addAll(links));
    for (final link in uniqueLinks) {
      link._captureDepth++;
    }
    try {
      return paint();
    } finally {
      for (final link in uniqueLinks) {
        link._captureDepth--;
      }
    }
  }
}
