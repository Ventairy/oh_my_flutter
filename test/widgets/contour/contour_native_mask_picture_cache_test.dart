import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_native_mask_picture_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ContourNativeMaskPictureCache cache;
  late ui.PictureRecorder recorder;
  late ui.Canvas canvas;
  late List<ui.Picture> recorded;
  void Function(ui.Picture)? previousOnCreate;

  void drawMask(ui.Canvas target) =>
      target.drawRect(const ui.Rect.fromLTWH(2, 2, 4, 4), ui.Paint()..color = const ui.Color(0xFFFFFFFF));

  void admit({
    required Object sourceId,
    required double amount,
    int sourceBytes = 256,
    void Function(ui.Canvas)? paint,
  }) {
    for (var request = 0; request < 2; request++) {
      cache.paint(canvas, sourceId: sourceId, amount: amount, sourceBytes: sourceBytes, paint: paint ?? drawMask);
    }
  }

  Future<Uint8List> pixels(ui.Picture picture) async {
    final image = await picture.toImage(16, 8);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return Uint8List.fromList(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  }

  setUp(() {
    cache = ContourNativeMaskPictureCache.test();
    recorder = ui.PictureRecorder();
    canvas = ui.Canvas(recorder);
    recorded = [];
    previousOnCreate = ui.Picture.onCreate;
    ui.Picture.onCreate = (picture) {
      previousOnCreate?.call(picture);
      recorded.add(picture);
    };
  });

  tearDown(() {
    if (recorder.isRecording) recorder.endRecording().dispose();
    cache.clear();
    for (final picture in recorded) {
      if (!picture.debugDisposed) picture.dispose();
    }
    ui.Picture.onCreate = previousOnCreate;
  });

  test('when an accepted source repeats an amount, it should reuse its recording', () {
    final sourceId = Object();
    var paints = 0;
    for (var owner = 0; owner < 3; owner++) {
      cache.paint(
        canvas,
        sourceId: sourceId,
        amount: 3,
        sourceBytes: 256,
        paint: (target) {
          paints++;
          drawMask(target);
        },
      );
    }
    expect((paints, cache.buildCount), (2, 1));
  });

  test('when an amount first appears, it should paint directly without recording', () {
    var paints = 0;
    cache.paint(
      canvas,
      sourceId: Object(),
      amount: 3,
      sourceBytes: 256,
      paint: (target) {
        paints++;
        drawMask(target);
      },
    );
    expect((paints, recorded.length, cache.buildCount, cache.entryCount), (1, 0, 0, 0));
  });

  test('when an amount changes on every request, it should never record those transient amounts', () {
    final sourceId = Object();
    var paints = 0;
    for (var amount = 0; amount < 200; amount++) {
      cache.paint(
        canvas,
        sourceId: sourceId,
        amount: amount.toDouble(),
        sourceBytes: 256,
        paint: (target) {
          paints++;
          drawMask(target);
        },
      );
    }
    expect((paints, recorded.length, cache.buildCount, cache.entryCount), (200, 0, 0, 0));
  });

  test('when an amount has no cached recording, it should report a cache miss', () {
    expect(cache.paintCached(canvas, sourceId: Object(), amount: 3), isFalse);
  });

  test('when an amount has a cached recording, it should paint without another source callback', () {
    final sourceId = Object();
    admit(sourceId: sourceId, amount: 3);
    expect(cache.paintCached(canvas, sourceId: sourceId, amount: 3), isTrue);
  });

  test('when a cached amount interrupts another amount, it should require a new consecutive repeat', () {
    final sourceId = Object();
    admit(sourceId: sourceId, amount: 1);
    cache
      ..paint(canvas, sourceId: sourceId, amount: 2, sourceBytes: 256, paint: drawMask)
      ..paintCached(canvas, sourceId: sourceId, amount: 1)
      ..paint(canvas, sourceId: sourceId, amount: 2, sourceBytes: 256, paint: drawMask);
    expect((cache.contains(sourceId, 2), cache.buildCount), (false, 1));
  });

  test('when two proofs share captured geometry, it should record each native backing separately', () {
    final capturedPath = ui.Path()..addRect(const ui.Rect.fromLTWH(2, 2, 4, 4));
    for (final sourceId in [Object(), Object()]) {
      admit(
        sourceId: sourceId,
        amount: 3,
        paint: (target) => target.drawPath(capturedPath, ui.Paint()..color = const ui.Color(0xFFFFFFFF)),
      );
    }
    expect(cache.buildCount, 2);
  });

  test('when shared captured geometry has different native backings, it should preserve each proof pixel', () async {
    final capturedPath = ui.Path()..addRect(const ui.Rect.fromLTWH(2, 2, 4, 4));
    admit(
      sourceId: Object(),
      amount: 3,
      paint: (target) => target.drawPath(capturedPath, ui.Paint()..color = const ui.Color(0xFFFFFFFF)),
    );
    canvas.translate(8, 0);
    admit(
      sourceId: Object(),
      amount: 3,
      paint: (target) => target.drawPath(
        capturedPath,
        ui.Paint()
          ..color = const ui.Color(0xFFFFFFFF)
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1,
      ),
    );
    final picture = recorder.endRecording();
    final rgba = await pixels(picture);
    expect((rgba[(4 * 16 + 4) * 4 + 3], rgba[(4 * 16 + 12) * 4 + 3]), (255, 0));
  });

  test('when a source exceeds four amounts, it should evict its least recently used amount', () {
    final sourceId = Object();
    for (final amount in [0.0, 1.0, 2.0, 3.0]) {
      admit(sourceId: sourceId, amount: amount);
    }
    cache.paintCached(canvas, sourceId: sourceId, amount: 0);
    admit(sourceId: sourceId, amount: 4);
    expect((cache.amountCount(sourceId), cache.contains(sourceId, 0), cache.contains(sourceId, 1)), (4, true, false));
  });

  test('when one source gains an amount, it should preserve another source amount allowance', () {
    final first = Object();
    final second = Object();
    for (final sourceId in [first, second]) {
      for (final amount in [0.0, 1.0, 2.0, 3.0]) {
        admit(sourceId: sourceId, amount: amount);
      }
    }
    admit(sourceId: first, amount: 4);
    expect((cache.amountCount(second), cache.contains(second, 0)), (4, true));
  });

  test('when an old amount is evicted, it should dispose that recording', () {
    final sourceId = Object();
    for (final amount in [0.0, 1.0, 2.0, 3.0, 4.0]) {
      admit(sourceId: sourceId, amount: amount);
    }
    expect(recorded.map((picture) => picture.debugDisposed), [true, false, false, false, false]);
  });

  test('when the entry limit is reached, it should evict the least recently used source', () {
    cache = ContourNativeMaskPictureCache.test(maximumEntries: 2);
    final sources = [Object(), Object(), Object()];
    for (final sourceId in sources) {
      admit(sourceId: sourceId, amount: 3);
    }
    expect((cache.entryCount, cache.contains(sources.first, 3)), (2, false));
  });

  test('when source resources exceed the global budget, it should evict earlier recordings', () {
    const sourceBytes = 2 * 1024 * 1024 + 1;
    final first = Object();
    final second = Object();
    admit(sourceId: first, amount: 3, sourceBytes: sourceBytes);
    admit(sourceId: second, amount: 3, sourceBytes: sourceBytes);
    expect(
      cache.entryCount == 1 &&
          !cache.contains(first, 3) &&
          cache.contains(second, 3) &&
          cache.estimatedBytes > sourceBytes &&
          cache.estimatedBytes <= ContourNativeMaskPictureCache.maximumEstimatedBytes,
      isTrue,
    );
  });

  test('when a picture is retained, it should charge its referenced source resources too', () {
    const sourceBytes = 12345;
    admit(sourceId: Object(), amount: 3, sourceBytes: sourceBytes);
    expect(cache.estimatedBytes, recorded.single.approximateBytesUsed + sourceBytes);
  });

  test('when a source alone reaches the byte budget, it should paint directly without retaining a picture', () {
    var paints = 0;
    admit(
      sourceId: Object(),
      amount: 3,
      sourceBytes: ContourNativeMaskPictureCache.maximumEstimatedBytes,
      paint: (target) {
        paints++;
        drawMask(target);
      },
    );
    expect((paints, recorded.length, cache.entryCount), (2, 0, 0));
  });

  test('when a new recording exceeds the byte budget, it should dispose the unretained recording', () {
    cache = ContourNativeMaskPictureCache.test(maximumBytes: 1);
    admit(sourceId: Object(), amount: 3, sourceBytes: 0);
    expect((cache.entryCount, recorded.single.debugDisposed), (0, true));
  });

  test('when retained pictures are cleared, it should dispose every recording and release its budget', () {
    final sourceId = Object();
    for (final amount in [1.0, 2.0, 3.0]) {
      admit(sourceId: sourceId, amount: amount);
    }
    cache.clear();
    expect(
      (cache.entryCount, cache.estimatedBytes, recorded.length, recorded.every((picture) => picture.debugDisposed)),
      (0, 0, 3, true),
    );
  });

  test('when more than 128 sources await repeated use, it should bound the admission tracker', () {
    for (var source = 0; source < 200; source++) {
      cache.paint(canvas, sourceId: Object(), amount: 3, sourceBytes: 256, paint: drawMask);
    }
    expect(cache.admissionSourceCount, 128);
  });

  test('when transient sources are cleared, it should release their admission history', () {
    for (var source = 0; source < 3; source++) {
      cache.paint(canvas, sourceId: Object(), amount: 3, sourceBytes: 256, paint: drawMask);
    }
    cache.clear();
    expect(cache.admissionSourceCount, 0);
  });

  test('when a recorded drawing outlives its cache, it should retain its exact pixels', () async {
    admit(sourceId: Object(), amount: 3);
    final picture = recorder.endRecording();
    final before = await pixels(picture);
    cache.clear();
    expect(await pixels(picture), before);
  });

  test('when an owned scene outlives its cached source pictures, it should retain their exact pixels', () async {
    final sourceId = Object();
    for (var request = 0; request < 2; request++) {
      cache.paint(canvas, sourceId: sourceId, amount: 3, sourceBytes: 256, paint: drawMask);
    }
    final picture = recorder.endRecording();
    final before = await pixels(picture);
    final scene = (ui.SceneBuilder()..addPicture(ui.Offset.zero, picture)).build();
    cache.clear();
    picture.dispose();
    try {
      final image = await scene.toImage(16, 8);
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        expect(data!.buffer.asUint8List(), before);
      } finally {
        image.dispose();
      }
    } finally {
      scene.dispose();
    }
  });
}
