part of 'morph_paint_probe.dart';

class _RenderMorphPaintProbe extends RenderProxyBox {
  new(this.onPaint);

  final VoidCallback onPaint;

  @override
  void paint(PaintingContext context, Offset offset) {
    onPaint();
    super.paint(context, offset);
  }
}
