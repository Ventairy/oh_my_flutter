import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:oh_my_flutter/src/widgets/contour/capture/contour_layer_picture_snapshot.dart';

/// Owns a source layer tree and an independent Canvas oracle.
class ContourLayerSnapshotTestFixture {
  /// Creates nested offset, transform, hard clip, and painted source layers.
  new() {
    _rootHandle.layer = root;
    root.append(offset);
    offset.append(transform);
    transform.append(clip);
    clip.append(leaf);
    leaf.picture = recordSource();
  }

  /// The capture grid used by the pixel fixtures.
  static const bounds = Rect.fromLTWH(-3, -4, 28, 30);

  /// Logical source coordinates intentionally exclude this root offset.
  final root = OffsetLayer(offset: const Offset(50, 60));

  /// A nested translation that must be included.
  final offset = OffsetLayer(offset: const Offset(3, 4));

  /// A nested affine transform that must be included.
  final transform = TransformLayer(
    transform: Matrix4.rotationZ(.2)..multiply(Matrix4.diagonal3Values(1.25, 1.25, 1)),
  );

  /// A hard clip that crosses both painted primitives.
  final clip = ClipRectLayer(clipRect: const Rect.fromLTWH(0, 0, 10, 12));

  /// The borrowed source picture owned by the live layer tree.
  final leaf = PictureLayer(const Rect.fromLTWH(-2, -2, 16, 16));
  final _rootHandle = LayerHandle<OffsetLayer>();
  final _snapshots = <ContourLayerPictureSnapshot>[];
  final _ownedPictures = <ui.Picture>[];

  /// Paints known geometry for source and oracle recordings.
  void paintSource(Canvas canvas) {
    canvas
      ..drawRect(
        const Rect.fromLTWH(-2, -2, 16, 16),
        Paint()..color = const Color(0xFFFF3344),
      )
      ..drawCircle(
        const Offset(8, 7),
        4,
        Paint()..color = const Color(0xFF2277FF),
      );
  }

  /// Records a replacement source whose ownership can pass to a PictureLayer.
  ui.Picture recordSource() {
    final recorder = ui.PictureRecorder();
    paintSource(Canvas(recorder));
    return recorder.endRecording();
  }

  /// Captures the current tree and retains its owned picture for cleanup.
  ContourLayerPictureSnapshot? capture({
    Rect grid = bounds,
    double ratio = 2,
    Matrix4? restingTransform,
  }) {
    final result = ContourLayerPictureSnapshot.captureChildren(
      root: root,
      bounds: grid,
      pixelRatio: ratio,
      generation: 7,
      transform: restingTransform,
    );
    if (result != null) _snapshots.add(result);
    return result;
  }

  /// Checks a stamp against the original source and capture metadata.
  bool current(
    ContourLayerSnapshotStamp stamp, {
    ContainerLayer? source,
    Rect grid = bounds,
    double ratio = 2,
    int generation = 7,
  }) => stamp.isCurrent(
    root: source ?? root,
    bounds: grid,
    pixelRatio: ratio,
    generation: generation,
  );

  /// Draws the expected tree directly, without traversing layers.
  ui.Picture expected({Matrix4? restingTransform}) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..scale(2)
      ..translate(3, 4);
    if (restingTransform != null) canvas.transform(restingTransform.storage);
    canvas
      ..translate(3, 4)
      ..transform(transform.transform!.storage)
      ..clipRect(const Rect.fromLTWH(0, 0, 10, 12), doAntiAlias: false);
    paintSource(canvas);
    final picture = recorder.endRecording();
    _ownedPictures.add(picture);
    return picture;
  }

  /// Reads exact RGBA coverage from a capture-sized image.
  Future<Uint8List> pixels(ui.Picture picture) async {
    final image = await picture.toImage(56, 60);
    try {
      return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// Retires owned recordings before releasing the live borrowed source tree.
  void dispose() {
    for (final snapshot in _snapshots) {
      snapshot.dispose();
    }
    for (final picture in _ownedPictures) {
      picture.dispose();
    }
    _rootHandle.layer = null;
  }
}
