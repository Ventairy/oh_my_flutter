import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_shadow_atlas_rasterizer.dart';

import 'contour_shadow_atlas_rasterizer_test_harness.dart';

void main() {
  testWidgets('when a shadow atlas is downsampled, it should preserve the previous asynchronous pixel result', (
    tester,
  ) async {
    final referenceSource = ContourShadowAtlasRasterizerTestHarness.createPicture();
    final harness = ContourShadowAtlasRasterizerTestHarness();
    ui.Picture? referenceDownsample;
    ui.Image? referenceIntermediate;
    ui.Image? reference;
    ui.Image? result;
    try {
      await tester.runAsync(() async {
        referenceIntermediate = await referenceSource.toImage(96, 72);
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawImageRect(
          referenceIntermediate!,
          const ui.Rect.fromLTWH(0, 0, 96, 72),
          const ui.Rect.fromLTWH(0, 0, 32, 24),
          ui.Paint()..filterQuality = ui.FilterQuality.low,
        );
        referenceDownsample = recorder.endRecording();
        reference = await referenceDownsample!.toImage(32, 24);
        result = await const ContourShadowAtlasRasterizer().rasterize(
          picture: harness.source,
          width: 96,
          height: 72,
          outputWidth: 32,
          outputHeight: 24,
        );
      });
      final expected = await tester.runAsync(() => reference!.toByteData());
      final actual = await tester.runAsync(() => result!.toByteData());
      expect(
        actual!.buffer.asUint8List(actual.offsetInBytes, actual.lengthInBytes),
        expected!.buffer.asUint8List(expected.offsetInBytes, expected.lengthInBytes),
      );
    } finally {
      result?.dispose();
      reference?.dispose();
      referenceIntermediate?.dispose();
      referenceDownsample?.dispose();
      referenceSource.dispose();
      harness.dispose();
    }
  });

  testWidgets('when rasterization succeeds, it should release every resource except the caller-owned result', (
    tester,
  ) async {
    final harness = ContourShadowAtlasRasterizerTestHarness();
    ui.Image? result;
    try {
      result = await tester.runAsync(
        () => const ContourShadowAtlasRasterizer().rasterize(
          picture: harness.source,
          width: 96,
          height: 72,
          outputWidth: 32,
          outputHeight: 24,
        ),
      );
      expect(
        (harness.allPicturesDisposed, harness.intermediatesDisposed(result!), harness.resultDisposed(result)),
        (true, true, false),
      );
    } finally {
      result?.dispose();
      harness.dispose();
    }
  });

  testWidgets('when a real intermediate cannot rasterize, it should return no image and dispose every owned resource', (
    tester,
  ) async {
    final harness = ContourShadowAtlasRasterizerTestHarness();
    Object? failure;
    ui.Image? result;
    try {
      await tester.runAsync(() async {
        try {
          result = await ContourShadowAtlasRasterizer.test(
            // The test rasterizer rejects this width before allocating a
            // bitmap. The failed image is genuine, alive, and never disposed
            // before use; final dimensions remain a small 32 by 24 image.
            createIntermediate: (picture, width, height) => picture.toImageSync(16385, 1),
          ).rasterize(picture: harness.source, width: 96, height: 72, outputWidth: 32, outputHeight: 24);
        } on Object catch (error) {
          failure = error;
        }
      });
      expect(
        (
          failure is ui.PictureRasterizationException &&
              (failure! as ui.PictureRasterizationException).message.contains('16385x1'),
          result,
          harness.allPicturesDisposed,
          harness.allImagesDisposed,
        ),
        (true, null, true, true),
      );
    } finally {
      result?.dispose();
      harness.dispose();
    }
  }, skip: kIsWeb);

  testWidgets('when intermediate creation throws synchronously, it should dispose the supplied source picture', (
    tester,
  ) async {
    final harness = ContourShadowAtlasRasterizerTestHarness();
    final expectedFailure = StateError('intermediate factory failed');
    Object? failure;
    ui.Image? result;
    try {
      await tester.runAsync(() async {
        try {
          result = await ContourShadowAtlasRasterizer.test(
            createIntermediate: (picture, width, height) => throw expectedFailure,
          ).rasterize(picture: harness.source, width: 96, height: 72, outputWidth: 32, outputHeight: 24);
        } on Object catch (error) {
          failure = error;
        }
      });
      expect(
        (identical(failure, expectedFailure), result, harness.allPicturesDisposed, harness.allImagesDisposed),
        (true, null, true, true),
      );
    } finally {
      result?.dispose();
      harness.dispose();
    }
  });

  testWidgets('when intermediate and output dimensions differ, it should keep both stages at their requested sizes', (
    tester,
  ) async {
    final harness = ContourShadowAtlasRasterizerTestHarness();
    (int, int)? requested;
    ui.Image? result;
    try {
      result = await tester.runAsync(
        () => ContourShadowAtlasRasterizer.test(
          createIntermediate: (picture, width, height) {
            requested = (width, height);
            return picture.toImageSync(width, height);
          },
        ).rasterize(picture: harness.source, width: 96, height: 72, outputWidth: 32, outputHeight: 24),
      );
      expect((requested, result!.width, result.height), ((96, 72), 32, 24));
    } finally {
      result?.dispose();
      harness.dispose();
    }
  });
}
