part of '../motion.dart';

class _MotionVertexGlyphBatch {
  new(ui.FragmentProgram program) : shader = program.fragmentShader();

  // Match the slot count and coordinate bands in the mesh shader.
  static const _capacity = 8;
  static const _coordinateBand = 2048;
  static const _coordinateInset = 512;
  static const maximumGlyphWidth = 1500;
  final ui.FragmentShader shader;
  final _paint = Paint()..isAntiAlias = false;
  final _positions = Float32List(8 * _capacity);
  final _textureCoords = Float32List(8 * _capacity);
  static final _indices = Uint16List.fromList([
    for (var n = 0; n < _capacity; n++) ...[4 * n, 4 * n + 1, 4 * n + 2, 4 * n + 1, 4 * n + 2, 4 * n + 3],
  ]);
  ui.Image? _image;
  var _count = 0;
  double _baseX = 0;

  int add(Canvas canvas, ui.Image image, Rect rect) {
    if (_count == _capacity ||
        !identical(_image, image) ||
        rect.left - _baseX <= -_coordinateInset ||
        rect.right - _baseX >= _coordinateBand - _coordinateInset) {
      flush(canvas);
    }
    if (_count == 0) {
      if (!identical(_image, image)) {
        _image = image;
        shader
          ..setImageSampler(0, image, filterQuality: FilterQuality.low)
          ..setFloat(0, image.width.toDouble())
          ..setFloat(1, image.height.toDouble());
      }
      _baseX = rect.left;
      shader.setFloat(2, _baseX);
    }
    final offset = 8 * _count;
    // Skia passes the texture coordinates to the runtime effect. Give each
    // glyph a disjoint X band while retaining its original sampling position.
    final encoded = _coordinateBand * _count + _coordinateInset - _baseX;
    _positions[offset] = rect.left;
    _positions[offset + 1] = rect.top;
    _positions[offset + 2] = rect.right;
    _positions[offset + 3] = rect.top;
    _positions[offset + 4] = rect.left;
    _positions[offset + 5] = rect.bottom;
    _positions[offset + 6] = rect.right;
    _positions[offset + 7] = rect.bottom;
    _textureCoords[offset] = rect.left + encoded;
    _textureCoords[offset + 1] = rect.top;
    _textureCoords[offset + 2] = rect.right + encoded;
    _textureCoords[offset + 3] = rect.top;
    _textureCoords[offset + 4] = rect.left + encoded;
    _textureCoords[offset + 5] = rect.bottom;
    _textureCoords[offset + 6] = rect.right + encoded;
    _textureCoords[offset + 7] = rect.bottom;
    final firstParameter = 3 + 16 * _count;
    _count++;
    return firstParameter;
  }

  void flush(Canvas canvas) {
    if (_count == 0) return;
    final vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.sublistView(_positions, 0, 8 * _count),
      textureCoordinates: Float32List.sublistView(_textureCoords, 0, 8 * _count),
      indices: Uint16List.sublistView(_indices, 0, 6 * _count),
    );
    _count = 0;
    try {
      canvas.drawVertices(vertices, BlendMode.src, _paint..shader = shader);
    } finally {
      vertices.dispose();
    }
  }

  void dispose() {
    _paint.shader = null;
    shader.dispose();
  }
}
