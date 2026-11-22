import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../benchmark/motion_blur/motion_blur_benchmark_probe.dart';

void main() {
  for (final warmed in [false, true]) {
    test('when wrapped glyph preparation reports $warmed, it should read that state', () {
      final render = _GlyphRenderBox(warmed);
      final parent = RenderIgnorePointer(child: render);
      final probe = MotionBlurBenchmarkProbe();
      addTearDown(() {
        parent
          ..child = null
          ..dispose();
        render.dispose();
        probe.dispose();
      });

      expect(probe.glyphShaderWarmed(parent), warmed);
    });
  }
}

class _GlyphRenderBox extends RenderProxyBox {
  new(this.warmed);

  final bool warmed;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('glyphBlurProgram', value: warmed, ifTrue: 'glyph blur shader warmed'));
  }
}
