import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_layer_snapshot_test_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContourLayerSnapshotTestFixture fixture;

  setUp(() => fixture = ContourLayerSnapshotTestFixture());
  tearDown(() => fixture.dispose());

  for (final transformed in [false, true]) {
    testWidgets(
      'when nested layers ${transformed ? 'enter a resting capture frame' : 'are captured'}, it should preserve exact Canvas coverage',
      (tester) async {
        final rest = transformed ? (Matrix4.rotationZ(.15)..setTranslationRaw(2, 1, 0)) : null;
        final snapshot = fixture.capture(restingTransform: rest)!;
        final expected = fixture.expected(restingTransform: rest);
        final pixels = (await tester.runAsync(
          () => Future.wait([
            fixture.pixels(snapshot.picture),
            fixture.pixels(expected),
          ]),
        ))!;
        expect(
          (
            listEquals(pixels[0], pixels[1]),
            pixels[0].any((value) => value != 0),
          ),
          (true, true),
        );
      },
    );
  }

  test(
    'when the frozen picture is released, it should keep a valid source stamp without disposing borrowed artwork',
    () {
      final snapshot = fixture.capture()!;
      final borrowed = fixture.leaf.picture!;
      snapshot
        ..releasePicture()
        ..releasePicture();
      expect(
        (
          snapshot.picture.debugDisposed,
          fixture.current(snapshot.stamp),
          borrowed.debugDisposed,
        ),
        (true, true, false),
      );
    },
  );

  test('when the snapshot is disposed, it should invalidate its stamp while preserving borrowed artwork', () {
    final snapshot = fixture.capture()!;
    final borrowed = fixture.leaf.picture!;
    snapshot
      ..dispose()
      ..dispose();
    expect(
      (
        snapshot.picture.debugDisposed,
        fixture.current(snapshot.stamp),
        borrowed.debugDisposed,
      ),
      (true, false, false),
    );
  });

  for (final effect in ['opacity', 'antialiased clip', 'unfinished picture']) {
    test(
      'when a source contains $effect, it should decline direct capture without taking borrowed picture ownership',
      () {
        switch (effect) {
          case 'opacity':
            fixture.root.append(OpacityLayer(alpha: 128));
          case 'antialiased clip':
            fixture.clip.clipBehavior = Clip.antiAlias;
          case 'unfinished picture':
            fixture.root.append(PictureLayer(Rect.zero));
        }
        expect(
          (fixture.capture(), fixture.leaf.picture!.debugDisposed),
          (null, false),
        );
      },
    );
  }

  for (final grid in [
    (
      name: 'zero ratio',
      bounds: ContourLayerSnapshotTestFixture.bounds,
      ratio: 0.0,
    ),
    (
      name: 'nonfinite ratio',
      bounds: ContourLayerSnapshotTestFixture.bounds,
      ratio: double.nan,
    ),
    (
      name: 'dimension overflow',
      bounds: const Rect.fromLTWH(0, 0, 4097, 1),
      ratio: 1.0,
    ),
    (
      name: 'pixel budget overflow',
      bounds: const Rect.fromLTWH(0, 0, 2000, 2000),
      ratio: 1.0,
    ),
  ]) {
    test(
      'when the grid has ${grid.name}, it should reject capture before borrowing source pixels',
      () {
        expect(fixture.capture(grid: grid.bounds, ratio: grid.ratio), isNull);
      },
    );
  }
}
