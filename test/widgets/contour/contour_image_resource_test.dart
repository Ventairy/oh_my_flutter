import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_shadow_pool_test_harness.dart';
import 'contour_test_harness.dart';

void main() {
  testWidgets('when a queued style becomes obsolete, it should retain only the latest shadow image', (tester) async {
    final harness = ContourShadowPoolTestHarness();
    await harness.mount(tester);
    await harness.mount(tester, amount: 5, settle: false);
    await tester.pump(const Duration(milliseconds: 16));
    await harness.mount(tester, amount: 7);
    expect(
      (
        harness.resourceIds(20).toSet().length,
        harness.resourceIds(20).contains(0),
        harness.property('shadowPoolEntries'),
      ),
      (1, false, 1),
    );
  });

  testWidgets('when some shared owners detach, it should preserve the image used by remaining owners', (tester) async {
    final harness = ContourShadowPoolTestHarness();
    await harness.mount(tester);
    await harness.mount(tester, amountFor: (index) => index < 10 ? 6 : 3);
    final retained = harness.resourceIds(20).first;
    await harness.mount(tester, count: 10, amount: 6);
    expect((harness.resourceIds(10).every((id) => id == retained), harness.property('shadowPoolEntries')), (true, 1));
  });

  testWidgets('when every shared owner detaches, it should release all image reservations', (tester) async {
    final harness = ContourShadowPoolTestHarness();
    await harness.mount(tester, count: 40);
    final sentinel = ContourTestHarness();
    await sentinel.mount(tester, child: const SizedBox.square(dimension: 1));
    Object? property(String name) => sentinel.backdropKey.currentContext!
        .findRenderObject()!
        .toDiagnosticsNode()
        .getProperties()
        .firstWhere((property) => property.name == name)
        .value;
    for (var attempt = 0; attempt < 100 && property('shadowPoolPending') != 0; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
    }
    expect((property('shadowPoolEntries'), property('shadowPoolPixels')), (0, 0));
  });
  testWidgets('when queued atlas owners detach, it should cancel their snapshots and release reservations', (
    tester,
  ) async {
    final harness = ContourShadowPoolTestHarness();
    List<Shadow> shadows(int index) => [
      Shadow(color: const Color(0x33000000), blurRadius: 6, offset: Offset(index / 10, 2)),
    ];
    await harness.mount(tester, count: 40, amount: 1, shadowsFor: shadows);
    for (final amount in [2.0, 3.0, 4.0]) {
      await tester.pump(const Duration(milliseconds: 60));
      await harness.mount(tester, count: 40, amount: amount, shadowsFor: shadows, settle: false);
    }
    await tester.pump(const Duration(milliseconds: 120));
    final queuedBeforeDetach = harness.property('shadowAtlasQueuedJobs')! as int;
    final sentinel = ContourTestHarness();
    await sentinel.mount(tester, child: const SizedBox.square(dimension: 1));
    Object? property(String name) => sentinel.backdropKey.currentContext!
        .findRenderObject()!
        .toDiagnosticsNode()
        .getProperties()
        .firstWhere((property) => property.name == name)
        .value;
    for (var attempt = 0; attempt < 400 && property('shadowPoolPending') != 0; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
    }
    expect(
      (
        queuedBeforeDetach > 0,
        property('shadowAtlasQueuedJobs'),
        property('shadowAtlasActiveJobs'),
        property('shadowAtlasSnapshotBytes'),
        property('shadowPoolPixels'),
        property('shadowPoolEntries'),
      ),
      (true, 0, 0, 0, 0, 0),
    );
  });
}
