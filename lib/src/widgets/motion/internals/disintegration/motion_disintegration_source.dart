part of '../../motion.dart';

class _MotionDisintegrationSource {
  const new({
    required this.image,
    required this.outputBounds,
    required this.fragments,
    this.regions,
    this.characterIndices,
    this.pixelRatio = 1,
  });

  final ui.Image image;
  final Rect outputBounds;
  final List<Rect> fragments;
  final List<Rect>? regions;
  final List<int>? characterIndices;
  final double pixelRatio;

  static Future<_MotionDisintegrationSource> capture(
    RenderRepaintBoundary boundary, {
    required bool isText,
    required double devicePixelRatio,
    required List<MotionEffect> effects,
    required double blurOutset,
    required bool capturesBlurredSource,
  }) async {
    final size = boundary.size;
    final text = isText ? _findText(boundary) : null;
    text?._prepareDeferredAtlas();
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
        outputBounds: _MotionDisintegrationBounds.calculate(
          size: size,
          fragments: fragments,
          effects: effects,
          blurOutset: blurOutset,
        ),
        fragments: fragments,
        regions: regions,
      );
    }

    final fragments = <Rect>[];
    final characterIndices = <int>[];
    if (text?._characterCenters case final centers?) {
      for (var index = 0; index < centers.length ~/ 2; index++) {
        final glyph = text!._glyphPainters[text._spriteIndexByCharacter[index]];
        final bounds = Rect.fromCenter(
          center: Offset(centers[index * 2], centers[index * 2 + 1]),
          width: glyph.width,
          height: glyph.height,
        ).intersect(Offset.zero & size);
        if (!bounds.isEmpty) {
          fragments.add(bounds);
          characterIndices.add(index);
        }
      }
    }
    if (fragments.isEmpty) fragments.add(Offset.zero & size);
    final outputBounds = _MotionDisintegrationBounds.calculate(
      size: size,
      fragments: fragments,
      effects: effects,
      // Widget blur after breakup is composited outside the particle surface.
      blurOutset: isText || capturesBlurredSource ? blurOutset : 0,
    );
    final pixelRatio = _MotionDisintegrationBounds.capturePixelRatio(
      sourceSize: size,
      outputSize: outputBounds.size,
      devicePixelRatio: devicePixelRatio,
      androidReadinessProbe: !isText && !capturesBlurredSource && !kIsWeb && defaultTargetPlatform == .android,
    );
    final image = text != null && text._previewScale != null
        ? await _captureSharpText(text, size, pixelRatio)
        : await boundary.toImage(pixelRatio: pixelRatio);
    return _MotionDisintegrationSource(
      image: image,
      outputBounds: outputBounds,
      fragments: fragments,
      regions: [
        for (final fragment in fragments)
          Rect.fromPoints(fragment.topLeft * pixelRatio, fragment.bottomRight * pixelRatio),
      ],
      pixelRatio: pixelRatio,
      characterIndices: characterIndices.isEmpty ? null : characterIndices,
    );
  }

  static Future<ui.Image> _captureSharpText(_RenderOptimizedTextMotion text, Size size, double ratio) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(ratio);
    text._paintContent(canvas, Offset.zero, applyBlur: false);
    final picture = recorder.endRecording();
    try {
      return await picture.toImage((size.width * ratio).ceil(), (size.height * ratio).ceil());
    } finally {
      picture.dispose();
    }
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
