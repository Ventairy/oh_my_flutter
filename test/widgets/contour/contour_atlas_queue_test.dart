import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_initial_frame_fence.dart';

import 'contour_shadow_atlas_test_harness.dart';
import 'contour_shadow_pool_test_harness.dart';
import 'contour_test_harness.dart';

void main() {
  Widget sharedChild(int index) => index == 2
      ? const SizedBox.square(dimension: 16, child: ColoredBox(color: Color(0xFFFF0000)))
      : const Padding(
          padding: EdgeInsets.all(4),
          child: Text(
            'OO',
            style: TextStyle(fontFamily: 'Ahem', fontSize: 24, color: Color(0xFFFF0000)),
          ),
        );

  List<Shadow> sharedShadows(int index, double offset) =>
      index == 2 ? const [] : [Shadow(color: const Color(0x33000000), blurRadius: 6, offset: Offset(offset, 2))];

  Future<void> primeSharedAtlas(
    WidgetTester tester,
    ContourShadowAtlasTestHarness harness, {
    required double offset,
  }) => harness.animate(
    tester,
    count: 3,
    shadowsFor: (index) => sharedShadows(index, offset),
    childFor: sharedChild,
  );

  Future<void> stageSharedAtlas(
    WidgetTester tester,
    ContourShadowAtlasTestHarness harness, {
    required double offset,
    bool Function(int)? showFor,
  }) => harness.mount(
    tester,
    count: 3,
    amount: 4,
    settle: false,
    showFor: showFor,
    shadowsFor: (index) => sharedShadows(index, offset),
    childFor: sharedChild,
  );

  testWidgets('when shared atlases wait for foreground work, it should dispatch after every hold ends', (tester) async {
    final harness = ContourShadowAtlasTestHarness();
    final fence = ContourInitialFrameFence.shared;
    var holds = 0;
    addTearDown(() {
      while (holds > 0) {
        fence.endForeground();
        holds--;
      }
    });
    await primeSharedAtlas(tester, harness, offset: .11);
    await stageSharedAtlas(tester, harness, offset: .21);
    await tester.pump(const Duration(milliseconds: 121));
    final queuedBeforeHold = harness.property('shadowAtlasQueuedJobs', 2);
    fence
      ..beginForeground()
      ..beginForeground();
    holds = 2;
    await tester.pump();
    final blocked = <Object?>[
      harness.property('shadowAtlasQueuedJobs', 2),
      harness.property('shadowAtlasActiveJobs', 2),
      harness.property('shadowAtlasTransientPixels', 2),
      harness.property('shadowAtlasReady'),
      harness.property('shadowAtlasReady', 1),
    ];
    fence.endForeground();
    holds--;
    await tester.pump();
    final oneHoldRemains = <Object?>[
      harness.property('shadowAtlasQueuedJobs', 2),
      harness.property('shadowAtlasActiveJobs', 2),
      harness.property('shadowAtlasTransientPixels', 2),
    ];
    fence.endForeground();
    holds--;
    await ContourTestHarness.settle(tester);
    expect(
      <Object?>[
        queuedBeforeHold,
        blocked,
        oneHoldRemains,
        harness.property('shadowAtlasReady'),
        harness.property('shadowAtlasReady', 1),
        harness.property('shadowAtlasResourceId') == harness.property('shadowAtlasResourceId', 1),
        harness.property('shadowAtlasQueuedJobs', 2),
        harness.property('shadowAtlasActiveJobs', 2),
        harness.property('shadowAtlasTransientPixels', 2),
      ],
      <Object?>[
        1,
        <Object?>[1, 0, 0, false, false],
        <Object?>[1, 0, 0],
        true,
        true,
        true,
        0,
        0,
        0,
      ],
    );
  });

  testWidgets('when every shared owner detaches during the fence, it should release queued artwork immediately', (
    tester,
  ) async {
    final harness = ContourShadowAtlasTestHarness();
    final fence = ContourInitialFrameFence.shared;
    var held = false;
    addTearDown(() {
      if (held) fence.endForeground();
    });
    await primeSharedAtlas(tester, harness, offset: .31);
    await stageSharedAtlas(tester, harness, offset: .41);
    await tester.pump(const Duration(milliseconds: 121));
    fence.beginForeground();
    held = true;
    await tester.pump();
    final blocked = <Object?>[
      harness.property('shadowAtlasQueuedJobs', 2),
      harness.property('shadowAtlasActiveJobs', 2),
      harness.property('shadowAtlasTransientPixels', 2),
      (harness.property('shadowAtlasSnapshotBytes', 2)! as int) > 0,
    ];
    await stageSharedAtlas(tester, harness, offset: .41, showFor: (index) => index != 0);
    final followerRetains = <Object?>[
      harness.property('shadowAtlasQueuedJobs', 2),
      harness.property('shadowPoolPending', 2),
      (harness.property('shadowAtlasSnapshotBytes', 2)! as int) > 0,
    ];
    await stageSharedAtlas(tester, harness, offset: .41, showFor: (index) => index == 2);
    await tester.runAsync(Future<void>.value);
    final cancelled = <Object?>[
      fence.ready,
      harness.property('shadowAtlasQueuedJobs', 2),
      harness.property('shadowAtlasActiveJobs', 2),
      harness.property('shadowAtlasTransientPixels', 2),
      harness.property('shadowAtlasSnapshotBytes', 2),
      harness.property('shadowPoolPending', 2),
    ];
    fence.endForeground();
    held = false;
    await ContourTestHarness.settle(tester);
    expect(
      <Object?>[blocked, followerRetains, cancelled],
      <Object?>[
        <Object?>[1, 0, 0, true],
        <Object?>[1, 1, true],
        <Object?>[false, 0, 0, 0, 0, 0],
      ],
    );
  });

  testWidgets('when another foreground epoch starts as the fence opens, it should wait for the current epoch', (
    tester,
  ) async {
    final harness = ContourShadowAtlasTestHarness();
    final fence = ContourInitialFrameFence.shared;
    var holds = 0;
    addTearDown(() {
      while (holds > 0) {
        fence.endForeground();
        holds--;
      }
    });
    await primeSharedAtlas(tester, harness, offset: .51);
    await stageSharedAtlas(tester, harness, offset: .61);
    await tester.pump(const Duration(milliseconds: 121));
    fence.beginForeground();
    holds++;
    var changedEpoch = false;
    final nextEpoch = fence.wait().then((_) {
      fence.beginForeground();
      holds++;
      changedEpoch = true;
    });
    await tester.pump();
    fence.endForeground();
    holds--;
    for (var attempt = 0; attempt < 400 && !changedEpoch; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 5));
    }
    final blockedAgain = <Object?>[
      changedEpoch,
      fence.ready,
      harness.property('shadowAtlasQueuedJobs', 2),
      harness.property('shadowAtlasActiveJobs', 2),
      harness.property('shadowAtlasTransientPixels', 2),
    ];
    if (!changedEpoch) throw StateError('The shared fence did not open for the first foreground epoch.');
    await nextEpoch;
    fence.endForeground();
    holds--;
    await ContourTestHarness.settle(tester);
    expect(
      <Object?>[
        blockedAgain,
        harness.property('shadowAtlasReady'),
        harness.property('shadowAtlasReady', 1),
        harness.property('shadowAtlasQueuedJobs', 2),
        harness.property('shadowAtlasActiveJobs', 2),
        harness.property('shadowAtlasTransientPixels', 2),
      ],
      <Object?>[
        <Object?>[true, false, 1, 0, 0],
        true,
        true,
        0,
        0,
        0,
      ],
    );
  });

  testWidgets('when many distinct atlases wait, it should bound active and transient GPU work', (tester) async {
    final harness = ContourShadowPoolTestHarness();
    List<Shadow> shadows(int index) => [
      Shadow(color: const Color(0x33000000), blurRadius: 6, offset: Offset(index / 10, 2)),
    ];
    await harness.mount(tester, count: 40, amount: 1, shadowsFor: shadows);
    for (final amount in [2.0, 3.0, 4.0]) {
      await tester.pump(const Duration(milliseconds: 60));
      await harness.mount(tester, count: 40, amount: amount, shadowsFor: shadows, settle: false);
    }
    var maximumQueued = 0;
    var maximumActive = 0;
    var maximumTransient = 0;
    var maximumRetained = 0;
    for (var frame = 0; frame < 80; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      maximumQueued = math.max(maximumQueued, harness.property('shadowAtlasQueuedJobs')! as int);
      maximumActive = math.max(maximumActive, harness.property('shadowAtlasActiveJobs')! as int);
      maximumTransient = math.max(maximumTransient, harness.property('shadowAtlasTransientPixels')! as int);
      maximumRetained = math.max(maximumRetained, harness.property('shadowPoolPixels')! as int);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
    }
    await ContourTestHarness.settle(tester);
    final ready = [for (var index = 0; index < 40; index++) harness.property('shadowAtlasReady', index)].contains(true);
    expect(
      (
        maximumQueued > 0,
        maximumQueued <= 64,
        maximumActive <= 2,
        maximumTransient <= 8 * 1024 * 1024,
        maximumRetained <= 4 * 1024 * 1024,
        ready,
      ),
      (true, true, true, true, true, true),
    );
  });
}
