part of 'maybe_safe_area.dart';

class _SafeAreaTransform {
  final Matrix4 _transform = Matrix4.identity();
  List<RenderObject>? _transformPath;

  void reset() {
    _transformPath = null;
  }

  Matrix4? resolve(RenderObject source) {
    final path = _validatedTransformPath(source);
    if (path == null) return null;
    return _resolveTransform(path);
  }

  Matrix4 _resolveTransform(List<RenderObject> path) {
    final result = _transform..setIdentity();
    for (var index = path.length - 2; index > 0; index -= 1) {
      final ancestor = path[index];
      if (ancestor is MaybeSafeAreaTransform && ancestor.usesRestingSafeAreaGeometry) {
        ancestor.applyRestingPaintTransform(path[index - 1], result);
      } else {
        ancestor.applyPaintTransform(path[index - 1], result);
      }
    }
    return result;
  }

  Matrix4? resolveResting(RenderObject source) {
    final path = _validatedTransformPath(source);
    if (path == null) return null;
    for (var index = 1; index + 1 < path.length; index++) {
      final ancestor = path[index];
      if (ancestor is MaybeSafeAreaTransform && ancestor.usesRestingSafeAreaGeometry) return _resolveTransform(path);
    }
    return null;
  }

  List<RenderObject>? _validatedTransformPath(RenderObject source) {
    final rootNode = source.owner?.rootNode;
    if (rootNode == null) return null;
    final cachedPath = _transformPath;
    if (cachedPath != null &&
        cachedPath.isNotEmpty &&
        identical(cachedPath.first, source) &&
        identical(cachedPath.last, rootNode)) {
      var valid = true;
      for (var index = 0; index + 1 < cachedPath.length; index += 1) {
        if (!identical(cachedPath[index].parent, cachedPath[index + 1])) {
          valid = false;
          break;
        }
      }
      if (valid) return cachedPath;
    }

    final path = (cachedPath ?? <RenderObject>[])..clear();
    RenderObject? node = source;
    while (node != null) {
      path.add(node);
      if (identical(node, rootNode)) {
        _transformPath = path;
        return path;
      }
      node = node.parent;
    }
    return null;
  }
}
