import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_layer_snapshot_test_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ContourLayerSnapshotTestFixture fixture;
  setUp(() => fixture = ContourLayerSnapshotTestFixture());
  tearDown(() => fixture.dispose());

  test('when a snapshot is retired, it should keep an independently copied source lease current', () {
    final snapshot = fixture.capture()!;
    final copy = snapshot.stamp.copy()!;
    snapshot.dispose();
    expect(
      (fixture.current(snapshot.stamp), fixture.current(copy)),
      (false, true),
    );
  });

  test('when a copied lease is invalidated, it should preserve the original source lease', () {
    final original = fixture.capture()!.stamp;
    final copy = original.copy()!..invalidate();
    expect((fixture.current(original), fixture.current(copy)), (true, false));
  });

  test('when an invalidated source lease is copied, it should decline the new lease', () {
    final stamp = fixture.capture()!.stamp..invalidate();
    expect(stamp.copy(), isNull);
  });

  for (final change in ['root', 'bounds', 'density', 'generation']) {
    test(
      'when capture $change changes, it should reject the previous source lease',
      () {
        final stamp = fixture.capture()!.stamp;
        final otherRoot = ContainerLayer();
        addTearDown(otherRoot.dispose);
        final current = switch (change) {
          'root' => fixture.current(stamp, source: otherRoot),
          'bounds' => fixture.current(
            stamp,
            grid: ContourLayerSnapshotTestFixture.bounds.shift(
              const Offset(.5, 0),
            ),
          ),
          'density' => fixture.current(stamp, ratio: 3),
          'generation' => fixture.current(stamp, generation: 8),
          _ => throw StateError('Unknown fixture'),
        };
        expect(current, false);
      },
    );
  }
}
