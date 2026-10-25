import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_layer_snapshot_test_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContourLayerSnapshotTestFixture fixture;
  setUp(() => fixture = ContourLayerSnapshotTestFixture());
  tearDown(() => fixture.dispose());

  for (final change in [
    'transform matrix',
    'offset',
    'clip bounds',
    'clip behavior',
    'picture',
    'added child',
    'removed child',
    'child order',
  ]) {
    test(
      'when a nested source changes its $change, it should invalidate copied layer values',
      () {
        PictureLayer? sibling;
        if (change == 'child order') {
          sibling = PictureLayer(Rect.zero)..picture = fixture.recordSource();
          fixture.clip.append(sibling);
        }
        final stamp = fixture.capture()!.stamp;
        switch (change) {
          case 'transform matrix':
            fixture.transform.transform!.storage[12] += .25;
          case 'offset':
            fixture.offset.offset += const Offset(.25, .5);
          case 'clip bounds':
            fixture.clip.clipRect = const Rect.fromLTWH(0, 0, 9, 12);
          case 'clip behavior':
            fixture.clip.clipBehavior = Clip.antiAlias;
          case 'picture':
            fixture.leaf.picture = fixture.recordSource();
          case 'added child':
            fixture.clip.append(
              PictureLayer(Rect.zero)..picture = fixture.recordSource(),
            );
          case 'removed child':
            fixture.clip.removeAllChildren();
          case 'child order':
            final first = LayerHandle(fixture.leaf);
            final second = LayerHandle(sibling);
            fixture.clip
              ..removeAllChildren()
              ..append(sibling!)
              ..append(fixture.leaf);
            first.layer = null;
            second.layer = null;
        }
        expect(fixture.current(stamp), false);
      },
    );
  }

  for (final bookkeeping in ['root placement', 'raster cache hints']) {
    test(
      'when changes affect only $bookkeeping, it should preserve the source lease',
      () {
        final stamp = fixture.capture()!.stamp;
        if (bookkeeping == 'root placement') {
          fixture.root.offset += const Offset(100, 200);
        } else {
          fixture.leaf
            ..isComplexHint = true
            ..willChangeHint = true;
        }
        expect(fixture.current(stamp), true);
      },
    );
  }
}
