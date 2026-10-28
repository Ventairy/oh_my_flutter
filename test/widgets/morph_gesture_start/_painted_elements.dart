part of 'gesture_start_scene.dart';

class _PaintedElements {
  static Future<({Rect bounds, int pixels})> green(WidgetTester tester, GlobalKey frame) async =>
      (await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(frame));
        // Read the last painted layer, even when post-frame reconciliation has
        // dirtied the next frame. Pumping again would hide the regression.
        final image = await (boundary.debugLayer! as OffsetLayer).toImage(Offset.zero & boundary.size);
        try {
          final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          var left = image.width;
          var top = image.height;
          var right = -1;
          var bottom = -1;
          var pixels = 0;
          for (var y = 0; y < image.height; y++) {
            for (var x = 0; x < image.width; x++) {
              final offset = (y * image.width + x) * 4;
              if (bytes.getUint8(offset) < 5 && bytes.getUint8(offset + 1) > 250 && bytes.getUint8(offset + 2) < 5) {
                pixels++;
                if (x < left) left = x;
                if (x > right) right = x;
                if (y < top) top = y;
                if (y > bottom) bottom = y;
              }
            }
          }
          return (
            bounds: pixels == 0
                ? Rect.zero
                : Rect.fromLTRB(left.toDouble(), top.toDouble(), (right + 1).toDouble(), (bottom + 1).toDouble()),
            pixels: pixels,
          );
        } finally {
          image.dispose();
        }
      }))!;
}
