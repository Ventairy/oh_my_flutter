part of '../../motion.dart';

class _MotionDisintegrationSource {
  const new({required this.image, required this.size, required this.fragments, this.regions});

  final ui.Image image;
  final Size size;
  final List<Rect> fragments;
  final List<Rect>? regions;

  static Future<_MotionDisintegrationSource> capture(RenderRepaintBoundary boundary, {required bool isText}) async {
    final size = boundary.size;
    final text = isText ? _findText(boundary) : null;
    if (text?._atlas != null && !text!._needsClipping && text._characterCenters != null) {
      final centers = text._characterCenters!;
      final fragments = <Rect>[];
      final regions = <Rect>[];
      for (var index = 0; index < centers.length ~/ 2; index++) {
        final sprite = text._sprites[text._spriteIndexByCharacter[index]];
        final region = Rect.fromLTRB(sprite.left, sprite.top, sprite.right, sprite.bottom);
        final origin = Offset(
          centers[index * 2] - sprite.anchorX / text._devicePixelRatio,
          centers[index * 2 + 1] - sprite.anchorY / text._devicePixelRatio,
        );
        fragments.add(origin & (region.size / text._devicePixelRatio));
        regions.add(region);
      }
      return _MotionDisintegrationSource(
        image: text._atlas!.clone(),
        size: size,
        fragments: fragments,
        regions: regions,
      );
    }

    final fragments = <Rect>[];
    if (text?._characterCenters case final centers?) {
      for (var index = 0; index < centers.length ~/ 2; index++) {
        final glyph = text!._glyphPainters[text._spriteIndexByCharacter[index]];
        final bounds = Rect.fromCenter(
          center: Offset(centers[index * 2], centers[index * 2 + 1]),
          width: glyph.width,
          height: glyph.height,
        ).intersect(Offset.zero & size);
        if (!bounds.isEmpty) fragments.add(bounds);
      }
    }
    if (fragments.isEmpty) fragments.add(Offset.zero & size);
    final image = await boundary.toImage(pixelRatio: 1);
    return _MotionDisintegrationSource(image: image, size: size, fragments: fragments);
  }

  static _RenderOptimizedTextMotion? _findText(RenderObject object) {
    if (object is _RenderOptimizedTextMotion) return object;
    _RenderOptimizedTextMotion? result;
    object.visitChildren((child) {
      result ??= _findText(child);
    });
    return result;
  }
}
