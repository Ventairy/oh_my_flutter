import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('when mesh glyphs use different blur strengths, it should sample each glyph independently', (
    tester,
  ) async {
    final alphas = await tester.runAsync(() async {
      final atlasRecorder = ui.PictureRecorder();
      ui.Canvas(atlasRecorder).drawRect(const ui.Rect.fromLTWH(3, 3, 1, 1), ui.Paint());
      final atlasPicture = atlasRecorder.endRecording();
      addTearDown(atlasPicture.dispose);
      final atlas = atlasPicture.toImageSync(8, 8);
      addTearDown(atlas.dispose);

      final program = await ui.FragmentProgram.fromAsset('shaders/motion_glyph_blur_mesh.frag');
      final shader = program.fragmentShader()
        ..setImageSampler(0, atlas, filterQuality: ui.FilterQuality.low)
        ..setFloat(0, 8)
        ..setFloat(1, 8)
        ..setFloat(2, 0);
      addTearDown(shader.dispose);

      void setGlyph(int slot, {required double origin, required double center, required double neighbor}) {
        final values = [origin, 0.0, 1.0, 0.0, 0.0, 0.0, 8.0, 8.0, center, neighbor, 0.0, 0.0, 0.0, 1.0];
        for (var index = 0; index < values.length; index++) {
          shader.setFloat(3 + 16 * slot + index, values[index]);
        }
      }

      setGlyph(0, origin: 0, center: 1, neighbor: 0);
      setGlyph(7, origin: 8, center: .5, neighbor: .25);
      const lastGlyphBand = 7 * 2048 + 512;
      final vertices = ui.Vertices.raw(
        ui.VertexMode.triangles,
        Float32List.fromList([0, 0, 8, 0, 0, 8, 8, 8, 8, 0, 16, 0, 8, 8, 16, 8]),
        textureCoordinates: Float32List.fromList([
          512,
          0,
          520,
          0,
          512,
          8,
          520,
          8,
          lastGlyphBand + 8,
          0,
          lastGlyphBand + 16,
          0,
          lastGlyphBand + 8,
          8,
          lastGlyphBand + 16,
          8,
        ]),
        indices: Uint16List.fromList([0, 1, 2, 1, 2, 3, 4, 5, 6, 5, 6, 7]),
      );
      addTearDown(vertices.dispose);
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawVertices(vertices, ui.BlendMode.src, ui.Paint()..shader = shader);
      final picture = recorder.endRecording();
      addTearDown(picture.dispose);
      final output = picture.toImageSync(16, 8);
      addTearDown(output.dispose);
      final pixels = (await output.toByteData())!;
      return [
        for (final x in [3, 4, 11, 12]) pixels.getUint8((3 * 16 + x) * 4 + 3),
      ];
    });

    expect(alphas, [255, 0, 64, 32]);
  }, skip: ui.ImageFilter.isShaderFilterSupported);
}
