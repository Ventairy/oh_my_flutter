import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/capture/contour_layer_picture_snapshot.dart';

import 'contour_snapshot_content_test_layer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bounds = Rect.fromLTWH(0, 0, 30, 30);
  late ContainerLayer root;
  late LayerHandle<ContainerLayer> handle;
  late ContourSnapshotContentTestLayer wrapper;
  late ContourSnapshotContentTestLayer decoration;
  late PictureLayer child;
  late List<ui.Picture> pictures;
  late List<ContourLayerPictureSnapshot> snapshots;

  ui.Picture record(void Function(Canvas) draw) {
    final recorder = ui.PictureRecorder();
    draw(Canvas(recorder));
    final picture = recorder.endRecording();
    pictures.add(picture);
    return picture;
  }

  ContourLayerPictureSnapshot? capture() {
    final snapshot = ContourLayerPictureSnapshot.captureChildren(
      root: root,
      bounds: bounds,
      pixelRatio: 2,
      generation: 1,
    );
    if (snapshot != null) snapshots.add(snapshot);
    return snapshot;
  }

  bool current(ContourLayerSnapshotStamp stamp) => stamp.isCurrent(
    root: root,
    bounds: bounds,
    pixelRatio: 2,
    generation: 1,
  );

  Future<Uint8List> pixels(ui.Picture picture) async {
    final image = await picture.toImage(60, 60);
    try {
      return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  setUp(() {
    root = ContainerLayer();
    handle = LayerHandle(root);
    pictures = [];
    snapshots = [];
    wrapper = ContourSnapshotContentTestLayer()..snapshotChildOffset = const Offset(3, 4);
    decoration = ContourSnapshotContentTestLayer()
      ..snapshotPictureOffset = const Offset(2, 1)
      ..snapshotPicture = record((canvas) {
        canvas.drawRect(const Rect.fromLTWH(0, 0, 7, 8), Paint()..color = const Color(0xFFFF0000));
      });
    child = PictureLayer(bounds)
      ..picture = record((canvas) {
        canvas.drawRect(const Rect.fromLTWH(1, 2, 3, 4), Paint()..color = const Color(0xFF0000FF));
      });
    root.append(wrapper);
    wrapper.append(decoration);
    decoration.append(child);
  });

  tearDown(() {
    for (final snapshot in snapshots) {
      snapshot.dispose();
    }
    handle.layer = null;
    for (final picture in pictures) {
      if (!picture.debugDisposed) picture.dispose();
    }
  });

  testWidgets('when owned decoration accompanies live children, it should preserve exact picture and child placement', (
    tester,
  ) async {
    final snapshot = capture()!;
    final expected = record((canvas) {
      canvas
        ..scale(2)
        ..translate(3, 4)
        ..save()
        ..translate(2, 1)
        ..drawPicture(decoration.snapshotPicture!)
        ..restore()
        ..drawPicture(child.picture!);
    });
    final images = (await tester.runAsync(() => Future.wait([pixels(snapshot.picture), pixels(expected)])))!;
    expect((listEquals(images[0], images[1]), images[0].any((value) => value != 0)), (true, true));
  });

  for (final change in [
    'decoration picture',
    'wrapper offset',
    'picture offset',
    'source validity',
    'child picture',
  ]) {
    test('when nested owned content changes its $change, it should reject the previous source lease', () {
      final stamp = capture()!.stamp;
      switch (change) {
        case 'decoration picture':
          decoration.snapshotPicture = record((canvas) {});
        case 'wrapper offset':
          wrapper.snapshotChildOffset += const Offset(.25, .5);
        case 'picture offset':
          decoration.snapshotPictureOffset += const Offset(.5, .25);
        case 'source validity':
          decoration.snapshotIsCurrent = false;
        case 'child picture':
          child.picture = record((canvas) {});
      }
      expect(current(stamp), false);
    });
  }

  test('when an owned decoration keeps unsupported live effects, it should decline direct capture', () {
    decoration.append(OpacityLayer(alpha: 128));
    expect(capture(), isNull);
  });

  for (final stale in [false, true]) {
    test(
      'when owned content has ${stale ? 'a stale source' : 'a nonfinite picture offset'}, it should decline before recording',
      () {
        if (stale) {
          decoration.snapshotIsCurrent = false;
        } else {
          decoration.snapshotPictureOffset = const Offset(double.nan, 0);
        }
        expect(capture(), isNull);
      },
    );
  }

  test('when an owned snapshot is released, it should preserve borrowed decoration and its copied source lease', () {
    final snapshot = capture()!;
    final copy = snapshot.stamp.copy()!;
    snapshot.dispose();
    expect((decoration.snapshotPicture!.debugDisposed, current(copy)), (false, true));
  });
}
