part of 'morph.dart';

class _MorphEndpointGeometry {
  _MorphEndpointGeometry({
    required this.renderObject,
    required this.localSize,
    required this.overlayBounds,
    required Matrix4 transform,
    required this.axisScale,
  }) : transform = Matrix4.copy(transform);

  RenderBox renderObject;
  Size localSize;
  Rect overlayBounds;
  final Matrix4 transform;
  Offset axisScale;

  void updateFrom(_MorphEndpointGeometry value) {
    renderObject = value.renderObject;
    localSize = value.localSize;
    overlayBounds = value.overlayBounds;
    transform.setFrom(value.transform);
    axisScale = value.axisScale;
  }
}
