import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour.dart';

void main() {
  const shadow = Shadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3));
  Map<String?, Object?> properties(GlobalKey key) => {
    for (final property in key.currentContext!.findRenderObject()!.toDiagnosticsNode().getProperties())
      property.name: property.value,
  };
  Widget scene(List<GlobalKey> keys, GlobalKey boundary, {double ratio = 3, Shadow? customShadow}) => MediaQuery(
    data: MediaQueryData(devicePixelRatio: ratio),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            color: const Color(0xfff3f4f6),
            child: SizedBox(
              width: 400,
              height: 500,
              child: Wrap(
                children: [
                  for (var index = 0; index < keys.length; index++)
                    SizedBox(
                      width: 80,
                      height: 60,
                      child: Center(
                        child: Contour(
                          key: keys[index],
                          amount: 4,
                          color: const Color(0xffffffff),
                          shadows: [customShadow ?? shadow],
                          child: Container(
                            width: 32,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xff157da7),
                              shape: index % 4 == 2 ? BoxShape.circle : BoxShape.rectangle,
                              borderRadius: index % 4 == 2
                                  ? null
                                  : BorderRadius.circular(switch (index % 4) {
                                      1 => 6,
                                      3 => 15,
                                      _ => 0,
                                    }),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Future<List<int>> pixels(WidgetTester tester, GlobalKey boundary, double ratio) async {
    final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = render.toImageSync(pixelRatio: ratio);
    final data = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba));
    final bytes = data!.buffer.asUint8List().toList();
    image.dispose();
    return bytes;
  }

  testWidgets(
    'when forty qualified boxes first paint, it should show the complete mesh shadow immediately',
    (
      tester,
    ) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1200, 1800);
      addTearDown(tester.view.reset);
      final support = ContourBoxGaussianShadowTestHarness.test(supported: true)..install();
      addTearDown(support.dispose);
      final keys = List.generate(40, (_) => GlobalKey());
      await tester.pumpWidget(scene(keys, GlobalKey()));
      final results = [for (final key in keys) properties(key)];
      expect(
        (
          results.where((value) => value['knownBoxFillActive'] == true).length,
          results.where((value) => value['firstPresentationHasContour'] == true).length,
          results.where((value) => value['boxGaussianMeshPaintCount'] == 1).length,
          results.where((value) => value['boxGaussianNativePaintCount'] == 0).length,
          results.where((value) => value['captureCount'] == 0).length,
          results.first['boxGaussianMeshCacheEntries'],
        ),
        (
          40,
          40,
          40,
          40,
          40,
          4,
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final ratio in [1.75, 3.0]) {
    testWidgets(
      'when actual default boxes use mesh shadows at DPR $ratio, it should stay within three RGB values of native Gaussian shadows',
      (
        tester,
      ) async {
        tester.view.devicePixelRatio = ratio;
        tester.view.physicalSize = const Size(1200, 1800);
        addTearDown(tester.view.reset);
        final meshSupport = ContourBoxGaussianShadowTestHarness.test(supported: true)..install();
        final meshBoundary = GlobalKey();
        await tester.pumpWidget(scene(List.generate(4, (_) => GlobalKey()), meshBoundary, ratio: ratio));
        final mesh = await pixels(tester, meshBoundary, ratio);
        await tester.pumpWidget(const SizedBox.shrink());
        meshSupport.dispose();
        final nativeSupport = ContourBoxGaussianShadowTestHarness.test(supported: false)..install();
        addTearDown(nativeSupport.dispose);
        final nativeBoundary = GlobalKey();
        await tester.pumpWidget(scene(List.generate(4, (_) => GlobalKey()), nativeBoundary, ratio: ratio));
        final native = await pixels(tester, nativeBoundary, ratio);
        var maximum = 0;
        for (var index = 0; index < mesh.length; index++) {
          maximum = math.max(maximum, (mesh[index] - native[index]).abs());
        }
        expect(maximum, lessThanOrEqualTo(3));
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'when physical sigma is below the mesh qualification floor, it should keep the native shadow immediately',
    (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1200, 1800);
      addTearDown(tester.view.reset);
      final support = ContourBoxGaussianShadowTestHarness.test(supported: true)..install();
      addTearDown(support.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        scene([key], GlobalKey(), customShadow: const Shadow(color: Color(0x33000000), blurRadius: 2.598077422706684)),
      );
      final result = properties(key);
      expect(
        (
          result['knownBoxFillActive'],
          result['firstPresentationHasContour'],
          result['boxGaussianMeshPaintCount'],
          result['boxGaussianNativePaintCount'],
        ),
        (
          true,
          true,
          0,
          1,
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
