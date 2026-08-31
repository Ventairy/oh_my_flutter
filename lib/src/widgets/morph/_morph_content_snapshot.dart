part of 'morph.dart';

final class _MorphContentSnapshot {
  _MorphContentSnapshot({
    required this.tiles,
    required this.size,
  }) {
    _painter = _MorphContentSnapshotPainter(
      tiles: tiles,
    );
  }

  factory _MorphContentSnapshot.tiled({
    required OffsetLayer layer,
    required Size size,
    required double pixelRatio,
  }) {
    final physicalWidth = (size.width * pixelRatio).ceil();
    final physicalHeight = (size.height * pixelRatio).ceil();
    final tiles = <_MorphContentSnapshotTile>[];
    for (var physicalTop = 0; physicalTop < physicalHeight; physicalTop += _maximumTilePhysicalExtent) {
      final tilePhysicalHeight = math.min(
        _maximumTilePhysicalExtent,
        physicalHeight - physicalTop,
      );
      for (var physicalLeft = 0; physicalLeft < physicalWidth; physicalLeft += _maximumTilePhysicalExtent) {
        final tilePhysicalWidth = math.min(
          _maximumTilePhysicalExtent,
          physicalWidth - physicalLeft,
        );
        final logicalBounds = Rect.fromLTWH(
          physicalLeft / pixelRatio,
          physicalTop / pixelRatio,
          tilePhysicalWidth / pixelRatio,
          tilePhysicalHeight / pixelRatio,
        );
        final atlas = _MorphSnapshotAtlas(
          layer.toImageSync(logicalBounds, pixelRatio: pixelRatio),
        );
        tiles.add(
          _MorphContentSnapshotTile(
            atlas: atlas,
            sourceRect:
                Offset.zero &
                Size(
                  tilePhysicalWidth.toDouble(),
                  tilePhysicalHeight.toDouble(),
                ),
            destinationRect: logicalBounds,
          ),
        );
      }
    }
    return _MorphContentSnapshot(tiles: tiles, size: size);
  }

  static const _maximumAtlasPhysicalExtent = 4096.0;
  static const int _maximumAtlasPhysicalPixels = 2048 * 2048;
  static const int _maximumCapturePhysicalPixels = 2048 * 2048;
  static const _maximumTilePhysicalExtent = 2048;
  static const _atlasGutterPhysicalExtent = 4.0;

  static ({
    List<_MorphContentSnapshot?> snapshots,
    int physicalPixels,
  })?
  captureAll({
    required double pixelRatio,
    required List<_RenderMorphDescendant> renderObjects,
  }) {
    if (renderObjects.isEmpty) {
      return (
        snapshots: const <_MorphContentSnapshot?>[],
        physicalPixels: 0,
      );
    }
    if (_plannedCapturePhysicalPixels(
          pixelRatio: pixelRatio,
          renderObjects: renderObjects,
        ) >
        _maximumCapturePhysicalPixels) {
      return null;
    }
    return _captureAllWithinBudget(
      pixelRatio: pixelRatio,
      renderObjects: renderObjects,
      remainingPhysicalPixels: _maximumCapturePhysicalPixels,
    );
  }

  static ({
    List<_MorphContentSnapshot?> snapshots,
    int physicalPixels,
  })?
  _captureAllWithinBudget({
    required double pixelRatio,
    required List<_RenderMorphDescendant> renderObjects,
    required int remainingPhysicalPixels,
  }) {
    if (renderObjects.isEmpty) {
      return (
        snapshots: const <_MorphContentSnapshot?>[],
        physicalPixels: 0,
      );
    }
    final layout = _atlasLayout(
      pixelRatio: pixelRatio,
      renderObjects: renderObjects,
    );
    final offsets = layout.offsets;
    final atlasSize = layout.size;
    final atlasPhysicalPixels = _physicalPixels(
      size: atlasSize,
      pixelRatio: pixelRatio,
    );
    final atlasExceedsTextureLimit = _atlasExceedsTextureLimit(
      size: atlasSize,
      pixelRatio: pixelRatio,
    );
    if (atlasExceedsTextureLimit && renderObjects.length > 1) {
      return _captureHalves(
        pixelRatio: pixelRatio,
        renderObjects: renderObjects,
        remainingPhysicalPixels: remainingPhysicalPixels,
      );
    }
    if (atlasSize.isEmpty) {
      return (
        snapshots: List<_MorphContentSnapshot?>.filled(
          renderObjects.length,
          null,
          growable: false,
        ),
        physicalPixels: 0,
      );
    }
    if (atlasPhysicalPixels > remainingPhysicalPixels) return null;

    final bounds = Offset.zero & atlasSize;
    final layer = OffsetLayer();
    final suppressedEndpoints = <_RenderMorphEndpoint>{};
    for (final renderObject in renderObjects) {
      renderObject.beginSnapshotCapture();
      _collectNestedEndpoints(renderObject, suppressedEndpoints, isRoot: true);
    }
    for (final endpoint in suppressedEndpoints) {
      endpoint.beginSnapshotSuppression();
    }

    try {
      FlutterErrorDetails? paintError;
      final previousOnError = FlutterError.onError;
      late FlutterExceptionHandler captureOnError;
      captureOnError = (details) => paintError ??= details;
      FlutterError.onError = captureOnError;
      final paintingContext = PaintingContext(layer, bounds);
      try {
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
      } finally {
        if (identical(FlutterError.onError, captureOnError)) {
          FlutterError.onError = previousOnError;
        }
      }
      final capturedPaintError = paintError;
      if (capturedPaintError != null) {
        Error.throwWithStackTrace(
          capturedPaintError.exception,
          capturedPaintError.stack ?? StackTrace.current,
        );
      }
      if (!layer.supportsRasterization()) {
        if (renderObjects.length > 1) {
          return _captureHalves(
            pixelRatio: pixelRatio,
            renderObjects: renderObjects,
            remainingPhysicalPixels: remainingPhysicalPixels,
          );
        }
        return (
          snapshots: List<_MorphContentSnapshot?>.filled(
            renderObjects.length,
            null,
            growable: false,
          ),
          physicalPixels: 0,
        );
      }
      if (atlasExceedsTextureLimit) {
        return (
          snapshots: <_MorphContentSnapshot?>[
            _MorphContentSnapshot.tiled(
              layer: layer,
              size: renderObjects.single.size,
              pixelRatio: pixelRatio,
            ),
          ],
          physicalPixels: atlasPhysicalPixels,
        );
      }
      final atlas = _MorphSnapshotAtlas(
        layer.toImageSync(bounds, pixelRatio: pixelRatio),
      );
      return (
        snapshots: List<_MorphContentSnapshot?>.generate(
          renderObjects.length,
          (index) {
            final size = renderObjects[index].size;
            final offset = offsets[index];
            return _MorphContentSnapshot(
              tiles: <_MorphContentSnapshotTile>[
                _MorphContentSnapshotTile(
                  atlas: atlas,
                  sourceRect: Rect.fromLTWH(
                    offset.dx * pixelRatio,
                    offset.dy * pixelRatio,
                    size.width * pixelRatio,
                    size.height * pixelRatio,
                  ),
                  destinationRect: Offset.zero & size,
                ),
              ],
              size: size,
            );
          },
          growable: false,
        ),
        physicalPixels: atlasPhysicalPixels,
      );
    } finally {
      for (final endpoint in suppressedEndpoints) {
        endpoint.endSnapshotSuppression();
      }
      for (final renderObject in renderObjects) {
        renderObject.endSnapshotCapture();
      }
      layer.dispose();
    }
  }

  static ({List<Offset> offsets, Size size}) _atlasLayout({
    required double pixelRatio,
    required List<_RenderMorphDescendant> renderObjects,
  }) {
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
    return (offsets: offsets, size: Size(atlasWidth, y + rowHeight));
  }

  static int _plannedCapturePhysicalPixels({
    required double pixelRatio,
    required List<_RenderMorphDescendant> renderObjects,
    int start = 0,
    int? end,
  }) {
    final rangeEnd = end ?? renderObjects.length;
    final count = rangeEnd - start;
    if (count == 0) return 0;
    final atlasSize = _atlasSize(
      pixelRatio: pixelRatio,
      renderObjects: renderObjects,
      start: start,
      end: rangeEnd,
    );
    if (_atlasExceedsTextureLimit(
          size: atlasSize,
          pixelRatio: pixelRatio,
        ) &&
        count > 1) {
      final midpoint = start + count ~/ 2;
      final first = _plannedCapturePhysicalPixels(
        pixelRatio: pixelRatio,
        renderObjects: renderObjects,
        start: start,
        end: midpoint,
      );
      if (first > _maximumCapturePhysicalPixels) return first;
      return first +
          _plannedCapturePhysicalPixels(
            pixelRatio: pixelRatio,
            renderObjects: renderObjects,
            start: midpoint,
            end: rangeEnd,
          );
    }
    return _physicalPixels(size: atlasSize, pixelRatio: pixelRatio);
  }

  static Size _atlasSize({
    required double pixelRatio,
    required List<_RenderMorphDescendant> renderObjects,
    required int start,
    required int end,
  }) {
    final count = end - start;
    final gutter = count == 1 ? 0.0 : _atlasGutterPhysicalExtent / pixelRatio;
    var totalArea = 0.0;
    var maximumWidth = 0.0;
    for (var index = start; index < end; index += 1) {
      final size = renderObjects[index].size;
      final packedWidth = size.width + gutter * 2;
      final packedHeight = size.height + gutter * 2;
      totalArea += packedWidth * packedHeight;
      maximumWidth = math.max(maximumWidth, packedWidth);
    }
    final targetWidth = math.max(maximumWidth, math.sqrt(totalArea));
    var x = 0.0;
    var y = 0.0;
    var rowHeight = 0.0;
    var atlasWidth = 0.0;
    for (var index = start; index < end; index += 1) {
      final size = renderObjects[index].size;
      final packedWidth = size.width + gutter * 2;
      final packedHeight = size.height + gutter * 2;
      if (x > 0 && x + packedWidth > targetWidth) {
        x = 0;
        y += rowHeight;
        rowHeight = 0;
      }
      x += packedWidth;
      rowHeight = math.max(rowHeight, packedHeight);
      atlasWidth = math.max(atlasWidth, x);
    }
    return Size(atlasWidth, y + rowHeight);
  }

  static bool _atlasExceedsTextureLimit({
    required Size size,
    required double pixelRatio,
  }) {
    final physicalWidth = (size.width * pixelRatio).ceil();
    final physicalHeight = (size.height * pixelRatio).ceil();
    return physicalWidth > _maximumAtlasPhysicalExtent ||
        physicalHeight > _maximumAtlasPhysicalExtent ||
        physicalWidth * physicalHeight > _maximumAtlasPhysicalPixels;
  }

  static int _physicalPixels({
    required Size size,
    required double pixelRatio,
  }) {
    return (size.width * pixelRatio).ceil() * (size.height * pixelRatio).ceil();
  }

  static ({
    List<_MorphContentSnapshot?> snapshots,
    int physicalPixels,
  })?
  _captureHalves({
    required double pixelRatio,
    required List<_RenderMorphDescendant> renderObjects,
    required int remainingPhysicalPixels,
  }) {
    final midpoint = renderObjects.length ~/ 2;
    final first = _captureAllWithinBudget(
      pixelRatio: pixelRatio,
      renderObjects: renderObjects.sublist(0, midpoint),
      remainingPhysicalPixels: remainingPhysicalPixels,
    );
    if (first == null) return null;
    final second = _captureAllWithinBudget(
      pixelRatio: pixelRatio,
      renderObjects: renderObjects.sublist(midpoint),
      remainingPhysicalPixels: remainingPhysicalPixels - first.physicalPixels,
    );
    if (second == null) return null;
    return (
      snapshots: <_MorphContentSnapshot?>[
        ...first.snapshots,
        ...second.snapshots,
      ],
      physicalPixels: first.physicalPixels + second.physicalPixels,
    );
  }

  final List<_MorphContentSnapshotTile> tiles;
  final Size size;
  late final _MorphContentSnapshotPainter _painter;
  late final Widget _widget = ClipRect(
    child: OverflowBox(
      alignment: Alignment.topLeft,
      minWidth: size.width,
      maxWidth: size.width,
      minHeight: size.height,
      maxHeight: size.height,
      child: CustomPaint(painter: _painter),
    ),
  );

  Widget build() => _widget;

  void addAtlasesTo(Set<_MorphSnapshotAtlas> atlases) {
    for (final tile in tiles) {
      atlases.add(tile.atlas);
    }
  }

  void retain() {
    for (final tile in tiles) {
      tile.atlas.retain();
    }
  }

  void release() {
    for (final tile in tiles) {
      tile.atlas.release();
    }
  }

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
