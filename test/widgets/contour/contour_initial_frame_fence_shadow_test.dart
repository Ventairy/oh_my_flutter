import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source_unsupported.dart' as unsupported;
import 'package:oh_my_flutter/src/widgets/contour/contour_initial_frame_fence.dart';

import 'contour_solid_test_painter.dart';

void main() {
  // Exercise the optional shadow snapshot used by the sampled fallback.
  setUp(() => ContourCompositeSource.testOverride = unsupported.ContourCompositeSource.shared);
  tearDown(() => ContourCompositeSource.testOverride = null);

  // This check requires a backend with supported frame IDs and raster timings.
  testWidgets('when the first paired raster is pending, it should postpone the optional shadow snapshot', (
    tester,
  ) async {
    final key = GlobalKey();
    final fence = ContourInitialFrameFence.shared;
    Object? property(String name) => key.currentContext!
        .findRenderObject()!
        .toDiagnosticsNode()
        .getProperties()
        .firstWhere((value) => value.name == name)
        .value;
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await tester.runAsync(() async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Contour(
              key: key,
              color: const Color(0xFFFFFFFF),
              amount: 4,
              shadows: const [Shadow(color: Color(0x18000000), blurRadius: 8)],
              child: const SizedBox.square(dimension: 20, child: CustomPaint(painter: ContourSolidTestPainter())),
            ),
          ),
        ),
      );
      for (var attempt = 0; attempt < 200 && property('contourReady') != true; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      for (var attempt = 0; attempt < 20; attempt++) {
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 2));
        if (fence.targetFrame >= 0) break;
      }
    });
    final buildsBeforeRaster = property('shadowCacheBuildCount');
    fence.reportRasterFinished(fence.targetFrame);
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 200 && property('shadowCacheReady') != true; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await tester.pump();
      }
    });
    expect(
      [
        buildsBeforeRaster,
        property('shadowCacheBuildCount'),
        property('shadowCacheReady'),
        property('traceCaptureCount'),
      ],
      [0, 1, true, 1],
    );
  }, skip: kIsWeb);
}
