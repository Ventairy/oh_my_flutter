import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'contour_layer_snapshot_content.dart';

part 'contour_layer_stamp.dart';
part 'contour_layer_snapshot_stamp.dart';

/// An owned picture of a known root's children, normalized to physical pixels.
///
/// Unsupported layer effects use the regular image capture instead. Call
/// [captureChildren] synchronously after the parent paint returns, when every
/// descendant PictureLayer has finished recording.
class ContourLayerPictureSnapshot {
  new _({
    required this.picture,
    required ui.Rect bounds,
    required double pixelRatio,
    required int generation,
    required ContainerLayer root,
    required List<_ContourLayerStamp> stamps,
  }) : stamp = ContourLayerSnapshotStamp._(
         root,
         bounds,
         pixelRatio,
         generation,
         stamps,
       );

  /// The independent picture, usable until [releasePicture] or [dispose].
  ///
  /// Borrow it synchronously when scheduling source capture. Only this snapshot
  /// may dispose it; do not reuse it after release.
  final ui.Picture picture;

  /// The release-safe source stamp for asynchronous publication checks.
  final ContourLayerSnapshotStamp stamp;
  bool _disposed = false;
  bool _pictureReleased = false;

  /// Records the children without building a Scene or changing borrowed layers.
  ///
  /// The caller must own [root] and know it is an offset-only wrapper. Its own
  /// scene behavior is deliberately excluded. Its offset cancels in the same
  /// way as OffsetLayer.toImage; passing an effect-bearing root would omit that
  /// effect. Descendants admit only exact standard PictureLayer, OffsetLayer,
  /// TransformLayer, hard ClipRectLayer, and plain ContainerLayer classes.
  /// Layers owned by Contour also expose their current recorded decoration.
  /// Unknown subclasses, unfinished pictures, effects, or excessive trees
  /// return null. [bounds] selects the output grid; it does not clip drawing.
  ///
  /// [transform] maps source coordinates into the selected capture frame.
  /// [generation] must change after repaint. [isCurrent] also detects public
  /// compositing properties and picture replacement without a repaint.
  static ContourLayerPictureSnapshot? captureChildren({
    required ContainerLayer root,
    required ui.Rect bounds,
    required double pixelRatio,
    required int generation,
    Matrix4? transform,
  }) {
    if (!_validGrid(bounds, pixelRatio) || transform != null && !_isFiniteAffine(transform.storage)) return null;
    final stamps = <_ContourLayerStamp>[];
    if (!_collectChildren(root, stamps, 0)) return null;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..scale(pixelRatio, pixelRatio)
      ..translate(-bounds.left, -bounds.top);
    if (transform != null) canvas.transform(transform.storage);
    _drawChildren(root, canvas);
    return ContourLayerPictureSnapshot._(
      picture: recorder.endRecording(),
      bounds: bounds,
      pixelRatio: pixelRatio,
      generation: generation,
      root: root,
      stamps: stamps,
    );
  }

  /// Checks source identity, revision, child order, pictures and layer values.
  ///
  /// Call this again before publishing an asynchronous result. It does not
  /// inspect debug-only scene dirtiness or engineLayer identities. The caller
  /// remains responsible for incrementing [generation] when its source paints.
  bool isCurrent({
    required ContainerLayer root,
    required ui.Rect bounds,
    required double pixelRatio,
    required int generation,
  }) {
    return !_disposed &&
        stamp.isCurrent(
          root: root,
          bounds: bounds,
          pixelRatio: pixelRatio,
          generation: generation,
        );
  }

  /// Releases the owned Picture while preserving the source stamp.
  ///
  /// Call after source capture has retained its own picture. The
  /// asynchronous result can still be checked with [isCurrent]. Repeated calls
  /// and a later [dispose] are safe.
  void releasePicture() {
    if (_pictureReleased) return;
    _pictureReleased = true;
    picture.dispose();
  }

  /// Invalidates pending results and releases the owned picture.
  ///
  /// Borrowed source pictures remain untouched. Repeated calls are safe.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    stamp.invalidate();
    releasePicture();
  }

  static bool _validGrid(ui.Rect bounds, double ratio) {
    if (!bounds.isFinite || bounds.isEmpty || !ratio.isFinite || ratio <= 0) return false;
    final width = (bounds.width * ratio).ceilToDouble();
    final height = (bounds.height * ratio).ceilToDouble();
    return width.isFinite &&
        height.isFinite &&
        width >= 1 &&
        height >= 1 &&
        width <= 4096 &&
        height <= 4096 &&
        width * height <= 3 * 1024 * 1024;
  }

  static bool _collectChildren(
    ContainerLayer parent,
    List<_ContourLayerStamp> stamps,
    int depth,
  ) {
    if (depth > 64) return false;
    for (var child = parent.firstChild; child != null; child = child.nextSibling) {
      if (stamps.length >= 1024) return false;
      final type = child.runtimeType;
      if (child case final ContourLayerSnapshotContent content) {
        final offset = content.snapshotChildOffset;
        final pictureOffset = content.snapshotPictureOffset;
        if (!content.snapshotIsCurrent ||
            !offset.dx.isFinite ||
            !offset.dy.isFinite ||
            !pictureOffset.dx.isFinite ||
            !pictureOffset.dy.isFinite) {
          return false;
        }
        stamps.add(
          _ContourLayerStamp(
            child,
            depth: depth,
            offset: offset,
            picture: content.snapshotPicture,
            pictureOffset: pictureOffset,
          ),
        );
      } else if (type == PictureLayer) {
        final picture = (child as PictureLayer).picture;
        if (picture == null) return false;
        stamps.add(_ContourLayerStamp(child, depth: depth, picture: picture));
      } else if (type == TransformLayer) {
        final layer = child as TransformLayer;
        final matrix = layer.transform;
        if (!layer.offset.dx.isFinite ||
            !layer.offset.dy.isFinite ||
            matrix == null ||
            !_isFiniteAffine(matrix.storage)) {
          return false;
        }
        stamps.add(
          _ContourLayerStamp(
            child,
            depth: depth,
            offset: layer.offset,
            transform: Float64List.fromList(matrix.storage),
          ),
        );
      } else if (type == OffsetLayer) {
        final layer = child as OffsetLayer;
        if (!layer.offset.dx.isFinite || !layer.offset.dy.isFinite) return false;
        stamps.add(
          _ContourLayerStamp(child, depth: depth, offset: layer.offset),
        );
      } else if (type == ClipRectLayer) {
        final layer = child as ClipRectLayer;
        if (layer.clipBehavior != ui.Clip.hardEdge || layer.clipRect == null || !layer.clipRect!.isFinite) {
          return false;
        }
        stamps.add(
          _ContourLayerStamp(
            child,
            depth: depth,
            clipRect: layer.clipRect,
            clipBehavior: layer.clipBehavior,
          ),
        );
      } else if (type == ContainerLayer) {
        stamps.add(_ContourLayerStamp(child, depth: depth));
      } else {
        return false;
      }
      if (child is ContainerLayer && !_collectChildren(child, stamps, depth + 1)) {
        return false;
      }
    }
    return true;
  }

  static bool _isFiniteAffine(Float64List m) =>
      m.every((value) => value.isFinite) &&
      m[2] == 0 &&
      m[3] == 0 &&
      m[6] == 0 &&
      m[7] == 0 &&
      m[8] == 0 &&
      m[9] == 0 &&
      m[10] == 1 &&
      m[11] == 0 &&
      m[14] == 0 &&
      m[15] == 1;

  static void _drawChildren(ContainerLayer parent, ui.Canvas canvas) {
    for (var child = parent.firstChild; child != null; child = child.nextSibling) {
      if (child case final ContourLayerSnapshotContent content) {
        canvas.save();
        final offset = content.snapshotChildOffset;
        canvas.translate(offset.dx, offset.dy);
        final picture = content.snapshotPicture;
        if (picture != null) {
          final pictureOffset = content.snapshotPictureOffset;
          canvas
            ..save()
            ..translate(pictureOffset.dx, pictureOffset.dy)
            ..drawPicture(picture)
            ..restore();
        }
        if (child is ContainerLayer) _drawChildren(child, canvas);
        canvas.restore();
      } else if (child.runtimeType == PictureLayer) {
        canvas.drawPicture((child as PictureLayer).picture!);
      } else {
        canvas.save();
        if (child.runtimeType == TransformLayer) {
          final layer = child as TransformLayer;
          canvas
            ..translate(layer.offset.dx, layer.offset.dy)
            ..transform(layer.transform!.storage);
        } else if (child.runtimeType == OffsetLayer) {
          final layer = child as OffsetLayer;
          canvas.translate(layer.offset.dx, layer.offset.dy);
        } else if (child.runtimeType == ClipRectLayer) {
          canvas.clipRect(
            (child as ClipRectLayer).clipRect!,
            doAntiAlias: false,
          );
        }
        _drawChildren(child as ContainerLayer, canvas);
        canvas.restore();
      }
    }
  }
}
