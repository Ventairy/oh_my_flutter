import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

part '_render_morph_paint_probe.dart';

class MorphPaintProbe extends SingleChildRenderObjectWidget {
  const new({required this.onPaint, super.child, super.key});

  final VoidCallback onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMorphPaintProbe(onPaint);
}
