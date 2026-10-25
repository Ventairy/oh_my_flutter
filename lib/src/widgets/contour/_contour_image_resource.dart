part of 'contour.dart';

class _ContourImageResource {
  new({
    required this.id,
    required this.key,
    required this.bounds,
    required this.width,
    required this.height,
    required this.pixels,
  });

  final int id;
  final Object key;
  final Rect bounds;
  final int width;
  final int height;
  final int pixels;
  final completion = Completer<ui.Image?>();
  ui.Image? image;
  int references = 1;
  int Function()? cancelQueued;
  bool removed = false;
}
