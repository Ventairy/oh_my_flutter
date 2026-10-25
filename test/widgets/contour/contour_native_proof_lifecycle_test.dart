import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source_unsupported.dart' as unsupported;
import 'package:oh_my_flutter/src/widgets/contour/contour_initial_frame_fence.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_native_proof_queue.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';

import 'contour_native_test_harness.dart';

void main() {
  // Exercise the sampled fallback's glyph-proof queue and lifecycle.
  setUp(() => ContourCompositeSource.testOverride = unsupported.ContourCompositeSource.shared);
  tearDown(() => ContourCompositeSource.testOverride = null);

  final budget = ContourWorkBudget.shared;
  final proofs = ContourNativeProofQueue.shared;

  Widget scene(ContourNativeTestHarness harness, {String text = 'O', double size = 24, Widget? source}) => MediaQuery(
    data: const MediaQueryData(devicePixelRatio: 2),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: harness.boundaryKey,
          child: SizedBox.square(
            dimension: 100,
            child: Center(
              child: Contour(
                key: harness.backdropKey,
                color: const Color(0xFF000000),
                amount: 3,
                child:
                    source ??
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(
                        text,
                        style: TextStyle(fontFamily: 'Ahem', fontSize: size, height: 1, color: const Color(0xFFE84A5F)),
                      ),
                    ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> waitWithoutPumping(bool Function() condition, {required String phase}) async {
    for (var attempt = 0; attempt < 400; attempt++) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw StateError('Contour did not reach $phase without another application frame.');
  }

  Future<void> waitForGeometry(ContourNativeTestHarness harness) => waitWithoutPumping(
    () =>
        harness.diagnostic('contourReady') == true &&
        proofs.initialWorkCount == 0 &&
        proofs.pendingCount == 1 &&
        !proofs.active &&
        budget.activeBytes == 0,
    phase: 'initial geometry with its proof still waiting for presentation',
  );

  Future<void> presentInitialGeometry(WidgetTester tester) async {
    final fence = ContourInitialFrameFence.shared;
    for (var attempt = 0; attempt < 40; attempt++) {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 5));
      if (fence.targetFrame >= 0 || fence.ready) break;
    }
    await waitWithoutPumping(
      () => fence.targetFrame >= 0 || fence.ready,
      phase: 'the fresh paired frame submission before proof admission',
    );
    // The test binding does not send native raster timings. Supply completion
    // only for the target that was actually submitted by the fresh-frame fence.
    if (fence.targetFrame >= 0) fence.reportRasterFinished(fence.targetFrame);
  }

  Future<void> finishRendering(WidgetTester tester, ContourNativeTestHarness harness) async {
    final fence = ContourInitialFrameFence.shared;
    for (var attempt = 0; attempt < 200; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 1));
      if (fence.targetFrame >= 0) fence.reportRasterFinished(fence.targetFrame);
      if (harness.diagnostic('generating') == false && !tester.binding.hasScheduledFrame) return;
    }
    throw StateError('Contour did not finish generating after submitted frames were rasterized.');
  }

  void cleanUp(WidgetTester tester, {required ContourWorkBudgetLease? Function() blocker}) {
    addTearDown(() async {
      await tester.runAsync(() async {
        try {
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          blocker()?.release();
        }
        await waitWithoutPumping(
          () =>
              !proofs.active &&
              proofs.pendingCount == 0 &&
              proofs.initialWorkCount == 0 &&
              budget.pendingCount == 0 &&
              budget.activeBytes == 0,
          phase: 'released proof and tracing resources during cleanup',
        );
      });
    });
  }

  Future<Uint8List> nativePixels(WidgetTester tester, ContourNativeTestHarness harness) async {
    final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
    final boundary = harness.boundaryKey.currentContext!.findRenderObject()!;
    final origin = paragraph.localToGlobal(Offset.zero, ancestor: boundary);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(4);
    final span = paragraph.text as TextSpan;
    for (final stroke in [false, true]) {
      TextPainter(
          text: TextSpan(
            text: span.text,
            style: span.style!.copyWith(
              foreground: Paint()
                ..color = const Color(0xFF000000)
                ..style = stroke ? PaintingStyle.stroke : PaintingStyle.fill
                ..strokeWidth = 6
                ..strokeJoin = StrokeJoin.round,
            ),
          ),
          textDirection: paragraph.textDirection,
        )
        ..layout(minWidth: paragraph.constraints.minWidth, maxWidth: paragraph.constraints.maxWidth)
        ..paint(canvas, origin)
        ..dispose();
    }
    TextPainter(text: paragraph.text, textDirection: paragraph.textDirection)
      ..layout(minWidth: paragraph.constraints.minWidth, maxWidth: paragraph.constraints.maxWidth)
      ..paint(canvas, origin)
      ..dispose();
    final picture = recorder.endRecording();
    try {
      final image = await tester.runAsync(() => picture.toImage(400, 400));
      try {
        final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
        return bytes!.buffer.asUint8List();
      } finally {
        image!.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  testWidgets(
    'when initial geometry is ready before presentation, it should defer proof capture until the paired scene',
    (
      tester,
    ) async {
      final harness = ContourNativeTestHarness();
      final builds = proofs.buildCount;
      cleanUp(tester, blocker: () => null);
      await tester.runAsync(() async {
        await tester.pumpWidget(scene(harness));
        await waitForGeometry(harness);
      });
      final beforePresentation = <Object?>[
        harness.diagnostic('traceCaptureCount'),
        harness.diagnostic('proofCaptureCount'),
        harness.diagnostic('nativeTextVerificationCount'),
        harness.diagnostic('firstPresentationFrameNumber'),
        proofs.pendingCount,
        proofs.active,
        proofs.initialWorkCount,
        proofs.buildCount - builds,
        budget.activeBytes,
      ];
      await tester.pump();
      await finishRendering(tester, harness);
      expect(
        <Object?>[
          beforePresentation,
          harness.diagnostic('traceCaptureCount'),
          harness.diagnostic('proofCaptureCount'),
          harness.diagnostic('nativeTextVerificationCount'),
          harness.diagnostic('nativeTextActive'),
          harness.diagnostic('firstPresentationHasContour'),
          proofs.pendingCount,
          proofs.active,
          proofs.initialWorkCount,
          proofs.buildCount - builds,
          proofs.maximumInitialWorkAtStart,
          budget.activeBytes,
          budget.pendingCount,
        ],
        <Object?>[
          [1, 0, 0, -1, 1, false, 0, 0, 0],
          1,
          1,
          1,
          true,
          true,
          0,
          false,
          0,
          1,
          0,
          0,
          0,
        ],
      );
    },
  );

  testWidgets(
    'when a proof waits for memory and the source changes, it should capture and verify only the latest source',
    (
      tester,
    ) async {
      final harness = ContourNativeTestHarness();
      final builds = proofs.buildCount;
      ContourWorkBudgetLease? blocker;
      cleanUp(tester, blocker: () => blocker);
      await tester.runAsync(() async {
        await tester.pumpWidget(scene(harness));
        await waitForGeometry(harness);
        blocker = await budget.request(bytes: budget.maxBytes, owner: Object()).future;
        await presentInitialGeometry(tester);
        await waitWithoutPumping(
          () => proofs.active && budget.pendingCount == 1,
          phase: 'the old proof waiting behind the full foreground reservation',
        );
      });
      final oldProofBlocked = <Object?>[
        harness.diagnostic('proofCaptureCount'),
        harness.diagnostic('nativeTextVerificationCount'),
        proofs.active,
        budget.activeBytes,
        budget.pendingCount,
      ];
      await tester.runAsync(() async {
        // Two Ahem glyphs visibly differ from one, so the exact native reference
        // also detects stale geometry rather than only stale proof accounting.
        await tester.pumpWidget(scene(harness, text: 'QQ'));
        await waitWithoutPumping(
          () => !proofs.active && proofs.pendingCount == 0 && proofs.initialWorkCount == 1 && budget.pendingCount == 1,
          phase: 'only the latest foreground trace waiting after stale proof cancellation',
        );
      });
      final latestTraceBlocked = <Object?>[
        harness.diagnostic('traceCaptureCount'),
        harness.diagnostic('proofCaptureCount'),
        harness.diagnostic('nativeTextVerificationCount'),
        proofs.active,
        proofs.pendingCount,
        proofs.initialWorkCount,
        budget.pendingCount,
      ];
      await tester.runAsync(() async {
        blocker!.release();
        await waitForGeometry(harness);
      });
      final latestGeometryReady = <Object?>[
        harness.diagnostic('traceCaptureCount'),
        harness.diagnostic('proofCaptureCount'),
        harness.diagnostic('nativeTextVerificationCount'),
      ];
      await tester.pump();
      await finishRendering(tester, harness);
      final actual = await harness.pixels(tester, pixelRatio: 4);
      final reference = await nativePixels(tester, harness);
      expect(
        <Object?>[
          oldProofBlocked,
          latestTraceBlocked,
          latestGeometryReady,
          harness.diagnostic('proofCaptureCount'),
          harness.diagnostic('nativeTextVerificationCount'),
          harness.diagnostic('nativeTextActive'),
          proofs.buildCount - builds,
          proofs.pendingCount,
          proofs.active,
          proofs.initialWorkCount,
          proofs.maximumInitialWorkAtStart,
          budget.pendingCount,
          budget.activeBytes,
          actual,
        ],
        <Object?>[
          [0, 0, true, budget.maxBytes, 1],
          [1, 0, 0, false, 0, 1, 1],
          [2, 0, 0],
          1,
          1,
          true,
          2,
          0,
          false,
          0,
          0,
          0,
          0,
          reference,
        ],
      );
    },
  );

  testWidgets(
    'when an owner detaches while its proof waits for memory, it should release work and restart for a fresh source',
    (
      tester,
    ) async {
      final harness = ContourNativeTestHarness();
      final builds = proofs.buildCount;
      ContourWorkBudgetLease? blocker;
      cleanUp(tester, blocker: () => blocker);
      await tester.runAsync(() async {
        await tester.pumpWidget(scene(harness));
        await waitForGeometry(harness);
        blocker = await budget.request(bytes: budget.maxBytes, owner: Object()).future;
        await presentInitialGeometry(tester);
        await waitWithoutPumping(
          () => proofs.active && budget.pendingCount == 1,
          phase: 'the detached owner proof waiting behind foreground memory',
        );
      });
      final detached = harness.backdropKey.currentContext!.findRenderObject()!;
      Object? detachedDiagnostic(String name) =>
          detached.toDiagnosticsNode().getProperties().firstWhere((property) => property.name == name).value;
      await tester.runAsync(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await waitWithoutPumping(
          () => !proofs.active && proofs.pendingCount == 0 && proofs.initialWorkCount == 0 && budget.pendingCount == 0,
          phase: 'cancelled owner resources draining while the foreground blocker remains held',
        );
      });
      final whileDetached = <Object?>[
        detachedDiagnostic('proofCaptureCount'),
        detachedDiagnostic('nativeTextVerificationCount'),
        budget.activeBytes,
        budget.pendingCount,
        proofs.pendingCount,
        proofs.active,
        proofs.initialWorkCount,
      ];
      blocker!.release();
      final fresh = ContourNativeTestHarness();
      await tester.pumpWidget(scene(fresh, text: 'OO', size: 24));
      await finishRendering(tester, fresh);
      expect(
        <Object?>[
          whileDetached,
          detachedDiagnostic('proofCaptureCount'),
          fresh.diagnostic('traceCaptureCount'),
          fresh.diagnostic('proofCaptureCount'),
          fresh.diagnostic('nativeTextVerificationCount'),
          fresh.diagnostic('nativeTextActive'),
          fresh.diagnostic('webActiveCount'),
          fresh.diagnostic('webQueuedPayloadBytes'),
          proofs.buildCount - builds,
          proofs.pendingCount,
          proofs.active,
          proofs.initialWorkCount,
          proofs.maximumInitialWorkAtStart,
          budget.activeBytes,
          budget.pendingCount,
        ],
        <Object?>[
          [0, 0, budget.maxBytes, 0, 0, false, 0],
          0,
          1,
          1,
          1,
          true,
          0,
          0,
          2,
          0,
          false,
          0,
          0,
          0,
          0,
        ],
      );
    },
  );

  testWidgets('when neutral source bounds change before proof admission, it should reject the obsolete proof', (
    tester,
  ) async {
    final harness = ContourNativeTestHarness();
    final paddingKey = GlobalKey();
    final builds = proofs.buildCount;
    ContourWorkBudgetLease? blocker;
    cleanUp(tester, blocker: () => blocker);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        scene(
          harness,
          source: Padding(
            key: paddingKey,
            padding: EdgeInsets.zero,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: SizedBox.square(dimension: 24, child: ContourNativeTestHarness.glyph),
            ),
          ),
        ),
      );
      await waitForGeometry(harness);
      blocker = await budget.request(bytes: budget.maxBytes, owner: Object()).future;
      await presentInitialGeometry(tester);
      await waitWithoutPumping(
        () => proofs.active && budget.pendingCount == 1,
        phase: 'the proof awaiting admission before a neutral bounds change',
      );
    });
    final padding = tester.renderObject<RenderPadding>(find.byKey(paddingKey));
    final capture = padding.parent! as RenderBox;
    final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
    final bounds = capture.paintBounds;
    final sourceSettings = (
      paragraph.text,
      paragraph.constraints,
      paragraph.paintBounds,
      paragraph.localToGlobal(Offset.zero, ancestor: capture),
    );
    // Layout alone changes the captured right bound. Fixed child constraints
    // keep the text, its painted ink, and its origin unchanged; no composition
    // callback has invalidated the old proof yet.
    padding.padding = const EdgeInsets.only(right: 12);
    tester.binding.rootPipelineOwner.flushLayout();
    final changedBoundsOnly = <Object?>[
      identical(tester.renderObject<RenderParagraph>(find.byType(RichText)), paragraph),
      (
            paragraph.text,
            paragraph.constraints,
            paragraph.paintBounds,
            paragraph.localToGlobal(Offset.zero, ancestor: capture),
          ) ==
          sourceSettings,
      capture.paintBounds.width > bounds.width,
    ];
    await tester.runAsync(() async {
      blocker!.release();
      await waitWithoutPumping(
        () =>
            !proofs.active &&
            proofs.pendingCount == 0 &&
            proofs.initialWorkCount == 0 &&
            budget.activeBytes == 0 &&
            budget.pendingCount == 0,
        phase: 'the obsolete bounds proof finishing without a capture or presentation',
      );
    });
    final rejectedBeforeComposition = <Object?>[
      harness.diagnostic('traceCaptureCount'),
      harness.diagnostic('proofCaptureCount'),
      harness.diagnostic('nativeTextVerificationCount'),
      harness.diagnostic('nativeTextActive'),
      proofs.buildCount - builds,
    ];
    await tester.pump();
    await finishRendering(tester, harness);
    final actual = await harness.pixels(tester, pixelRatio: 4);
    final reference = await nativePixels(tester, harness);
    expect(
      <Object?>[
        changedBoundsOnly,
        rejectedBeforeComposition,
        harness.diagnostic('traceCaptureCount'),
        harness.diagnostic('proofCaptureCount'),
        harness.diagnostic('nativeTextVerificationCount'),
        harness.diagnostic('nativeTextActive'),
        proofs.buildCount - builds,
        proofs.pendingCount,
        proofs.active,
        proofs.initialWorkCount,
        budget.activeBytes,
        budget.pendingCount,
        actual,
      ],
      <Object?>[
        [true, true, true],
        [1, 0, 0, false, 1],
        2,
        1,
        1,
        true,
        2,
        0,
        false,
        0,
        0,
        0,
        reference,
      ],
    );
  });
}
