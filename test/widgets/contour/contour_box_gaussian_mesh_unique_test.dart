import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour.dart';

void main() {
  testWidgets('when forty unique boxes first paint, it should keep every complete mesh shadow within the live budget', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1200, 1800);
    addTearDown(tester.view.reset);
    final support = ContourBoxGaussianShadowTestHarness.test(supported: true)..install();
    addTearDown(support.dispose);
    final keys = List.generate(40, (_) => GlobalKey());
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 3),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 400,
              height: 400,
              child: Wrap(
                children: [
                  for (var index = 0; index < keys.length; index++)
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: Center(
                        child: Contour(
                          key: keys[index],
                          amount: 4,
                          color: const Color(0xffffffff),
                          shadows: const [Shadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3))],
                          child: Container(
                            width: 18 + index * .2,
                            height: 17 + index * .15,
                            decoration: BoxDecoration(
                              color: const Color(0xff157da7),
                              shape: index % 4 == 2 ? BoxShape.circle : BoxShape.rectangle,
                              borderRadius: index % 4 == 2
                                  ? null
                                  : BorderRadius.circular(
                                      index % 4 == 0
                                          ? 0
                                          : index % 4 == 1
                                          ? 3
                                          : 7,
                                    ),
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
    );
    final results = [
      for (final key in keys)
        {
          for (final property in key.currentContext!.findRenderObject()!.toDiagnosticsNode().getProperties())
            property.name: property.value,
        },
    ];
    final probe = GlobalKey();
    await tester.pumpWidget(
      Contour(key: probe, amount: 0, color: const Color(0x00000000), child: const SizedBox.shrink()),
    );
    final retired = {
      for (final property in probe.currentContext!.findRenderObject()!.toDiagnosticsNode().getProperties())
        property.name: property.value,
    };
    expect(
      (
        results.where((r) => r['knownBoxFillActive'] == true).length,
        results.where((r) => r['firstPresentationHasContour'] == true).length,
        results.where((r) => r['boxGaussianMeshPaintCount'] == 1).length,
        results.where((r) => r['captureCount'] == 0).length,
        (results.first['boxGaussianMeshActiveBytes']! as int) <= 2 * 1024 * 1024,
        retired['boxGaussianMeshActiveBytes'],
        retired['boxGaussianMeshActiveEntries'],
        (retired['boxGaussianMeshRetainedBytes']! as int) <= 512 * 1024,
        (retired['boxGaussianMeshRetainedEntries']! as int) <= 16,
      ),
      (
        40,
        40,
        40,
        40,
        true,
        0,
        0,
        true,
        true,
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
