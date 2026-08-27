part of 'morph.dart';

final class _MorphContentSnapshot {
  _MorphContentSnapshot({
    required this.atlas,
    required this.sourceRect,
    required this.size,
  }) {
    _painter = _MorphContentSnapshotPainter(
      atlas: atlas,
      sourceRect: sourceRect,
    );
  }

  static const _maximumAtlasPhysicalExtent = 4096.0;
  static const _atlasGutterPhysicalExtent = 4.0;

  static List<_MorphContentSnapshot?> captureAll({
    required double pixelRatio,
    required List<_RenderMorphDescendant> renderObjects,
  }) {
    if (renderObjects.isEmpty) return const <_MorphContentSnapshot?>[];

    final gutter = renderObjects.length == 1 ? 0.0 : _atlasGutterPhysicalExtent / pixelRatio;
    var totalArea = 0.0;
    var maximumWidth = 0.0;
    for (final renderObject in renderObjects) {
      final packedWidth = renderObject.size.width + gutter * 2;
      final packedHeight = renderObject.size.height + gutter * 2;
      totalArea += packedWidth * packedHeight;
      maximumWidth = math.max(maximumWidth, packedWidth);
    }
    final targetWidth = math.max(maximumWidth, math.sqrt(totalArea));
    final offsets = List<Offset>.filled(
      renderObjects.length,
      Offset.zero,
      growable: false,
    );
    var x = 0.0;
    var y = 0.0;
    var rowHeight = 0.0;
    var atlasWidth = 0.0;
    for (var index = 0; index < renderObjects.length; index += 1) {
      final size = renderObjects[index].size;
      final packedWidth = size.width + gutter * 2;
      final packedHeight = size.height + gutter * 2;
      if (x > 0 && x + packedWidth > targetWidth) {
        x = 0;
        y += rowHeight;
        rowHeight = 0;
      }
      offsets[index] = Offset(x + gutter, y + gutter);
      x += packedWidth;
      rowHeight = math.max(rowHeight, packedHeight);
      atlasWidth = math.max(atlasWidth, x);
    }
    final atlasSize = Size(atlasWidth, y + rowHeight);
    final atlasExceedsTextureLimit =
        atlasSize.width * pixelRatio > _maximumAtlasPhysicalExtent ||
        atlasSize.height * pixelRatio > _maximumAtlasPhysicalExtent;
    if (atlasExceedsTextureLimit && renderObjects.length > 1) {
      return _captureHalves(
        pixelRatio: pixelRatio,
        renderObjects: renderObjects,
      );
    }
    if (atlasSize.isEmpty) {
      return List<_MorphContentSnapshot?>.filled(
        renderObjects.length,
        null,
        growable: false,
      );
    }
    final bounds = Offset.zero & atlasSize;
    final layer = OffsetLayer();
    final suppressedEndpoints = <_RenderMorphEndpoint>{};
    for (final renderObject in renderObjects) {
      _collectNestedEndpoints(renderObject, suppressedEndpoints, isRoot: true);
    }
    for (final endpoint in suppressedEndpoints) {
      endpoint._setSnapshotSuppressed(true);
    }

    try {
      final paintingContext = PaintingContext(layer, bounds);
      for (var index = 0; index < renderObjects.length; index += 1) {
        final renderObject = renderObjects[index];
        paintingContext.pushClipRect(
          renderObject.needsCompositing,
          offsets[index],
          Offset.zero & renderObject.size,
          renderObject.paint,
        );
      }
      // PaintingContext exposes this method to render-object implementations;
      // this capture performs the same offscreen paint operation.
      // ignore: invalid_use_of_protected_member
      paintingContext.stopRecordingIfNeeded();
      if (!layer.supportsRasterization()) {
        if (renderObjects.length > 1) {
          return _captureHalves(
            pixelRatio: pixelRatio,
            renderObjects: renderObjects,
          );
        }
        return List<_MorphContentSnapshot?>.filled(
          renderObjects.length,
          null,
          growable: false,
        );
      }
      final atlas = _MorphSnapshotAtlas(
        layer.toImageSync(
          bounds,
          pixelRatio: pixelRatio,
        ),
      );
      return List<_MorphContentSnapshot?>.generate(
        renderObjects.length,
        (index) {
          final size = renderObjects[index].size;
          final offset = offsets[index];
          return _MorphContentSnapshot(
            atlas: atlas,
            sourceRect: Rect.fromLTWH(
              offset.dx * pixelRatio,
              offset.dy * pixelRatio,
              size.width * pixelRatio,
              size.height * pixelRatio,
            ),
            size: size,
          );
        },
        growable: false,
      );
    } finally {
      for (final endpoint in suppressedEndpoints) {
        endpoint._setSnapshotSuppressed(false);
      }
      layer.dispose();
    }
  }

  static List<_MorphContentSnapshot?> _captureHalves({
    required double pixelRatio,
    required List<_RenderMorphDescendant> renderObjects,
  }) {
    final midpoint = renderObjects.length ~/ 2;
    return <_MorphContentSnapshot?>[
      ...captureAll(
        pixelRatio: pixelRatio,
        renderObjects: renderObjects.sublist(0, midpoint),
      ),
      ...captureAll(
        pixelRatio: pixelRatio,
        renderObjects: renderObjects.sublist(midpoint),
      ),
    ];
  }

  final _MorphSnapshotAtlas atlas;
  final Rect sourceRect;
  final Size size;
  late final _MorphContentSnapshotPainter _painter;

  Widget build() {
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: size.width,
        maxWidth: size.width,
        minHeight: size.height,
        maxHeight: size.height,
        child: CustomPaint(painter: _painter),
      ),
    );
  }

  void retain() => atlas.retain();

  void release() => atlas.release();

  static void _collectNestedEndpoints(
    RenderObject renderObject,
    Set<_RenderMorphEndpoint> result, {
    required bool isRoot,
  }) {
    if (!isRoot && renderObject is _RenderMorphEndpoint) {
      result.add(renderObject);
      return;
    }
    renderObject.visitChildren(
      (child) => _collectNestedEndpoints(child, result, isRoot: false),
    );
  }
}
