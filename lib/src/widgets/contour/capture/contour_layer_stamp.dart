part of 'contour_layer_picture_snapshot.dart';

/// A weak identity and copied value stamp; it never owns source pictures.
class _ContourLayerStamp {
  new(
    Layer source, {
    required this.depth,
    this.offset,
    this.transform,
    this.clipRect,
    this.clipBehavior,
    this.pictureOffset,
    ui.Picture? picture,
  }) : layer = WeakReference<Layer>(source),
       picture = picture == null ? null : WeakReference<ui.Picture>(picture);

  final WeakReference<Layer> layer;
  final int depth;
  final WeakReference<ui.Picture>? picture;
  final ui.Offset? offset;
  final Float64List? transform;
  final ui.Rect? clipRect;
  final ui.Clip? clipBehavior;
  final ui.Offset? pictureOffset;

  bool matches(Layer current, int currentDepth) {
    if (depth != currentDepth || !identical(layer.target, current)) return false;
    if (current case final ContourLayerSnapshotContent content) {
      return content.snapshotIsCurrent &&
          offset == content.snapshotChildOffset &&
          pictureOffset == content.snapshotPictureOffset &&
          identical(picture?.target, content.snapshotPicture);
    }
    if (current.runtimeType == PictureLayer) {
      final sourcePicture = picture?.target;
      return sourcePicture != null && identical(sourcePicture, (current as PictureLayer).picture);
    }
    if (current.runtimeType == TransformLayer) {
      final value = current as TransformLayer;
      final matrix = value.transform;
      if (offset != value.offset || matrix == null) return false;
      for (var i = 0; i < 16; i++) {
        if (transform![i] != matrix.storage[i]) return false;
      }
      return true;
    }
    if (current.runtimeType == OffsetLayer) {
      return offset == (current as OffsetLayer).offset;
    }
    if (current.runtimeType == ClipRectLayer) {
      final value = current as ClipRectLayer;
      return clipRect == value.clipRect && clipBehavior == value.clipBehavior;
    }
    return current.runtimeType == ContainerLayer;
  }
}
