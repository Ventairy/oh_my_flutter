import 'package:flutter/rendering.dart';

import '../contour/contour_benchmark_properties_builder.dart';

/// Reads renderer diagnostics before measured playback.
class MotionBlurBenchmarkProbe extends RenderProxyBox {
  /// Reports whether the text renderer has completed glyph shader preparation.
  bool? glyphShaderWarmed(RenderObject render) {
    final diagnostics = ContourBenchmarkPropertiesBuilder();
    render.debugFillProperties(diagnostics);
    for (final property in diagnostics.properties.whereType<FlagProperty>()) {
      if (property.name == 'glyphBlurProgram') return property.value;
    }
    bool? warmed;
    render.visitChildren((child) => warmed ??= glyphShaderWarmed(child));
    return warmed;
  }
}
