import 'package:flutter/rendering.dart';
import 'package:meta/meta.dart';

/// Supplies the stable layout frame before temporary paint animation effects.
///
/// This is an internal capability shared by rendering features. It is not
/// exported from the package's consumer library.
@internal
abstract interface class RestingPaintTransform {
  /// Appends this parent's stable transform for [child] to [transform].
  void applyRestingPaintTransform(RenderObject child, Matrix4 transform);

  /// Returns the source's stable transform in its owning view's logical space.
  ///
  /// Static transforms are preserved. Only parents implementing this capability
  /// can replace their temporary paint effects with a stable layout transform.
  /// The view's logical-to-physical device transform is excluded.
  static Matrix4? toView(RenderObject source) {
    final path = <RenderObject>[];
    RenderObject? node = source;
    while (node != null && node is! RenderView) {
      if (path.length >= 256) return null;
      path.add(node);
      node = node.parent;
    }
    if (node is! RenderView) return null;
    final result = Matrix4.identity();
    for (var i = path.length - 1; i > 0; i--) {
      final parent = path[i];
      final child = path[i - 1];
      if (parent is RestingPaintTransform) {
        (parent as RestingPaintTransform).applyRestingPaintTransform(
          child,
          result,
        );
      } else {
        parent.applyPaintTransform(child, result);
      }
    }
    return result.storage.every((v) => v.isFinite) ? result : null;
  }
}
