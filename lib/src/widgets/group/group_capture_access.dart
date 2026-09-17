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
  }) {
    final geometry = link._geometry(relativeTo);
    if (geometry == null) return null;
    final output = bounds ?? geometry.bounds;
    if (!output.isFinite || output.isEmpty) return null;
    final pixels = (output.width * pixelRatio).ceil() * (output.height * pixelRatio).ceil();
    if (pixels > RasterSnapshot.maximumCapturePhysicalPixels) return null;
    final before = revision(link, relativeTo);
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
      if (paintError != null || !layer.supportsRasterization() || before != revision(link, relativeTo)) return null;
      final snapshot = RasterSnapshot.tiled(layer: layer, size: output.size, pixelRatio: pixelRatio);
      return GroupSnapshot._(output, snapshot, pixelRatio);
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
  static int? revision(GroupLink link, RenderBox reference) {
    final geometry = link._geometry(reference);
    if (geometry == null) return null;
    return Object.hashAll(
      geometry.members.map(
        (entry) => Object.hash(
          entry.$1,
          entry.$1._revision,
          entry.$1.size,
          entry.$1.zIndex,
          Object.hashAll(entry.$2.storage),
        ),
      ),
    );
  }

  /// Temporarily suppresses the registered originals without changing layout.
  static GroupPresentationLease hide(GroupLink link) => GroupPresentationLease._(link);
}
