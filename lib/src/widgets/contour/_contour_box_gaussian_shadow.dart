part of 'contour.dart';

class _ContourBoxGaussianShadow {
  new({bool? supported})
    : _supported =
          supported ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && !ui.ImageFilter.isShaderFilterSupported);

  final bool _supported;
  final _meshes = <Shadow, ({_ContourBoxGaussianMesh mesh, Offset center})>{};
  final _paint = Paint();
  _ContourKnownBoxGeometry? _geometry;
  List<Shadow>? _shadows;
  double? _amount;
  double? _pixelRatio;
  bool _eligible = false;
  int meshPaintCount = 0;
  int meshVertexCount = 0;
  int meshTriangleCount = 0;

  bool accepts(_ContourKnownBoxGeometry? geometry, double amount, List<Shadow> shadows, double? pixelRatio) {
    if (!_supported || geometry == null) return false;
    final shape = geometry.roundedRect.inflate(amount);
    final radius = shape.tlRadiusX;
    if (shape.tlRadiusY != radius ||
        shape.trRadiusX != radius ||
        shape.trRadiusY != radius ||
        shape.blRadiusX != radius ||
        shape.blRadiusY != radius ||
        shape.brRadiusX != radius ||
        shape.brRadiusY != radius) {
      return false;
    }
    var hasBlur = false;
    for (final shadow in shadows) {
      if (shadow.color.a == 0 || shadow.blurRadius == 0) continue;
      hasBlur = true;
      if (shadow.runtimeType != Shadow ||
          shadow.color.runtimeType != Color ||
          shadow.color.colorSpace != ui.ColorSpace.sRGB ||
          shadow.color.r != 0 ||
          shadow.color.g != 0 ||
          shadow.color.b != 0 ||
          shadow.color.a > .2 ||
          radius / shadow.blurSigma > 5) {
        return false;
      }
      if (pixelRatio != null) {
        final sigma = shadow.blurSigma * pixelRatio;
        // The sigma-6 controls exceed the native comparison tolerance. The
        // next qualified physical sigma includes the default DPR-1.75 shadow.
        if (sigma + 1e-9 < const Shadow(blurRadius: 6).blurSigma * 1.75 || sigma > 40) return false;
      }
    }
    return hasBlur;
  }

  void configure(_ContourKnownBoxGeometry? geometry, double amount, List<Shadow> shadows, double? pixelRatio) {
    final styleChanged = !identical(_geometry, geometry) || !identical(_shadows, shadows) || _amount != amount;
    if (!styleChanged && _pixelRatio == pixelRatio) return;
    if (styleChanged) _releaseMeshes();
    _geometry = geometry;
    _shadows = shadows;
    _amount = amount;
    _pixelRatio = pixelRatio;
    _eligible = pixelRatio != null && accepts(geometry, amount, shadows, pixelRatio);
    if (!_eligible) {
      _releaseMeshes();
      return;
    }
    if (_meshes.isNotEmpty) return;
    final shape = geometry!.roundedRect.inflate(amount);
    for (final shadow in shadows) {
      if (shadow.color.a == 0 || shadow.blurRadius == 0 || _meshes.containsKey(shadow)) continue;
      final rect = shape.outerRect.shift(shadow.offset);
      final inverseSigma = 1 / shadow.blurSigma;
      final radius = shape.tlRadiusX;
      final capBase = rect.height / 2 - radius;
      final values = Float32List(18)
        ..[3] = rect.width / 2 * inverseSigma
        ..[4] = capBase * inverseSigma;
      const nodes = [0.0694318442029737, 0.3300094782075719, 0.6699905217924281, 0.9305681557970262];
      for (var i = 0; i < nodes.length; i++) {
        final delta = radius * nodes[i];
        values[5 + i] = (capBase + delta) * inverseSigma;
        values[9 + i] =
            (rect.width / 2 - radius + math.sqrt(math.max(0, radius * radius - delta * delta))) * inverseSigma;
      }
      values[13] = radius * inverseSigma * 0.1994711402007163;
      final mesh = _ContourBoxGaussianMeshCache.obtain(values, rect.height / 2 * inverseSigma, radius * inverseSigma);
      if (mesh != null) _meshes[shadow] = (mesh: mesh, center: rect.center);
    }
  }

  bool paint(Canvas canvas, Shadow shadow) {
    if (!_eligible) return false;
    final placement = _meshes[shadow];
    if (placement == null) return false;
    _paint
      ..color = shadow.color
      ..blendMode = BlendMode.srcOver;
    canvas
      ..save()
      ..translate(placement.center.dx, placement.center.dy)
      ..scale(shadow.blurSigma)
      ..drawVertices(placement.mesh.vertices, BlendMode.dst, _paint)
      ..restore();
    meshPaintCount++;
    meshVertexCount = placement.mesh.vertexCount;
    meshTriangleCount = placement.mesh.triangleCount;
    return true;
  }

  void _releaseMeshes() {
    for (final placement in _meshes.values) {
      _ContourBoxGaussianMeshCache.release(placement.mesh);
    }
    _meshes.clear();
  }

  void dispose() {
    _geometry = null;
    _shadows = null;
    _eligible = false;
    _releaseMeshes();
  }
}
