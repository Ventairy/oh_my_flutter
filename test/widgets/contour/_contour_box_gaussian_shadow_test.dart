import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour.dart';

import 'contour_box_gaussian_test_fixture.dart';

void main() {
  late ContourBoxGaussianTestFixture fixture;
  setUp(() => fixture = ContourBoxGaussianTestFixture());
  tearDown(() => fixture.dispose());

  testWidgets('when mesh support is unavailable, it should present the complete native shadow immediately', (
    tester,
  ) async {
    fixture.dispose();
    fixture = ContourBoxGaussianTestFixture(supported: false);
    await tester.pumpWidget(fixture.scene());
    final values = fixture.values;
    expect(
      (
        values['boxGaussianMeshPaintCount'],
        values['firstPresentationHasContour'],
        values['lastMainCompositionHasContent'],
        (values['boxGaussianNativePaintCount']! as int) > 0,
        values['captureCount'],
      ),
      (0, true, true, true, 0),
    );
  });

  for (final platform in TargetPlatform.values.where((platform) => platform != TargetPlatform.android)) {
    testWidgets('when the platform is ${platform.name}, it should present its native shadow immediately', (
      tester,
    ) async {
      fixture.dispose();
      fixture = ContourBoxGaussianTestFixture(supported: null);
      await tester.pumpWidget(fixture.scene());
      final values = fixture.values;
      expect(
        (
          values['boxGaussianMeshPaintCount'],
          values['firstPresentationHasContour'],
          (values['boxGaussianNativePaintCount']! as int) > 0,
          values['captureCount'],
        ),
        (0, true, true, 0),
      );
    }, variant: TargetPlatformVariant.only(platform));
  }

  testWidgets('when a qualified box first paints, it should present its content, contour and mesh shadow together', (
    tester,
  ) async {
    await tester.pumpWidget(fixture.scene());
    final values = fixture.values;
    expect(
      (
        values['lastMainCompositionHasContent'],
        values['firstPresentationHasContour'],
        values['boxGaussianMeshPaintCount'],
        values['boxGaussianNativePaintCount'],
        values['captureCount'],
      ),
      (true, true, 1, 0, 0),
    );
  });

  testWidgets('when a mesh owner is removed, it should dispose without a rendering exception', (tester) async {
    await tester.pumpWidget(fixture.scene());
    final firstValues = fixture.values;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(
      (
        firstValues['boxGaussianMeshPaintCount'],
        firstValues['firstPresentationHasContour'],
        firstValues['captureCount'],
        tester.takeException(),
      ),
      (1, true, 0, null),
    );
  });

  testWidgets('when physical sigma is six, it should paint the complete native scene immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      fixture.scene(
        shadows: const [Shadow(color: Color(0x33000000), blurRadius: (6 - .5) / .57735)],
      ),
    );
    final values = fixture.values;
    expect(
      (
        values['boxGaussianMeshPaintCount'],
        values['firstPresentationHasContour'],
        values['captureCount'],
        (values['boxGaussianNativePaintCount']! as int) > 0,
      ),
      (
        0,
        true,
        0,
        true,
      ),
    );
  });

  testWidgets('when physical sigma is below six, it should paint the complete native shadow', (
    tester,
  ) async {
    await tester.pumpWidget(fixture.scene(shadows: const [Shadow(color: Color(0x33000000), blurRadius: 8)]));
    await fixture.finish(tester);
    final values = fixture.values;
    expect(
      (
        values['boxGaussianMeshPaintCount'],
        values['firstPresentationHasContour'],
        values['captureCount'],
        (values['boxGaussianNativePaintCount']! as int) > 0,
      ),
      (
        0,
        true,
        0,
        true,
      ),
    );
  });

  testWidgets('when physical sigma exceeds forty, it should paint the complete native shadow', (
    tester,
  ) async {
    await tester.pumpWidget(fixture.scene(shadows: const [Shadow(color: Color(0x33000000), blurRadius: 70)]));
    await fixture.finish(tester);
    final values = fixture.values;
    expect(
      (
        values['boxGaussianMeshPaintCount'],
        values['firstPresentationHasContour'],
        values['captureCount'],
        (values['boxGaussianNativePaintCount']! as int) > 0,
      ),
      (
        0,
        true,
        0,
        true,
      ),
    );
  });

  testWidgets(
    'when the default low-density shadow uses DPR one point seven five, it should paint the qualified mesh immediately',
    (tester) async {
      await tester.pumpWidget(
        fixture.scene(pixelRatio: 1.75, shadows: const [Shadow(color: Color(0x33000000), blurRadius: 6)]),
      );
      final values = fixture.values;
      expect(
        (
          values['boxGaussianMeshPaintCount'],
          values['firstPresentationHasContour'],
          values['captureCount'],
          values['boxGaussianNativePaintCount'],
        ),
        (
          1,
          true,
          0,
          0,
        ),
      );
    },
  );

  testWidgets('when no visible blur exists, it should leave Gaussian meshes unused', (tester) async {
    await tester.pumpWidget(
      fixture.scene(
        shadows: const [
          Shadow(color: Color(0x33000000)),
          Shadow(color: Color(0x00000000), blurRadius: 20),
        ],
      ),
    );
    await fixture.finish(tester);
    final values = fixture.values;
    expect(
      (
        values['boxGaussianMeshPaintCount'],
        values['firstPresentationHasContour'],
        values['captureCount'],
      ),
      (
        0,
        true,
        0,
      ),
    );
  });

  testWidgets('when a tinted positive blur exists, it should retain native color handling', (
    tester,
  ) async {
    await tester.pumpWidget(fixture.scene(shadows: const [Shadow(color: Color(0x33202020), blurRadius: 20)]));
    await fixture.finish(tester);
    final values = fixture.values;
    expect(
      (
        values['boxGaussianMeshPaintCount'],
        values['firstPresentationHasContour'],
        values['captureCount'],
        (values['boxGaussianNativePaintCount']! as int) > 0,
      ),
      (
        0,
        true,
        0,
        true,
      ),
    );
  });

  testWidgets('when a stronger positive blur exists, it should retain the complete native shadow', (
    tester,
  ) async {
    await tester.pumpWidget(fixture.scene(shadows: const [Shadow(color: Color(0x66000000), blurRadius: 20)]));
    await fixture.finish(tester);
    final values = fixture.values;
    expect(
      (
        values['boxGaussianMeshPaintCount'],
        values['firstPresentationHasContour'],
        values['captureCount'],
        (values['boxGaussianNativePaintCount']! as int) > 0,
      ),
      (
        0,
        true,
        0,
        true,
      ),
    );
  });

  testWidgets(
    'when visible positive blurs have mixed qualification, it should retain native shadows for the complete scene',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        fixture.scene(
          shadows: const [
            Shadow(color: Color(0x33000000), blurRadius: 20),
            Shadow(color: Color(0x33000000), blurRadius: 8),
          ],
        ),
      );
      await fixture.finish(tester);
      final values = fixture.values;
      expect(
        (
          values['boxGaussianMeshPaintCount'],
          values['firstPresentationHasContour'],
          values['captureCount'],
          (values['boxGaussianNativePaintCount']! as int) > 0,
        ),
        (
          0,
          true,
          0,
          true,
        ),
      );
    },
  );

  testWidgets(
    'when a zero-blur shadow accompanies a qualified blur, it should paint the qualified mesh immediately',
    (tester) async {
      await tester.pumpWidget(
        fixture.scene(
          shadows: const [
            Shadow(color: Color(0x33000000)),
            Shadow(color: Color(0x33000000), blurRadius: 20),
          ],
        ),
      );
      final values = fixture.values;
      expect(
        (
          values['boxGaussianMeshPaintCount'],
          values['firstPresentationHasContour'],
          values['captureCount'],
          values['boxGaussianNativePaintCount'],
        ),
        (
          1,
          true,
          0,
          0,
        ),
      );
    },
  );

  testWidgets('when corners have unequal radii, it should retain the complete native shadow', (
    tester,
  ) async {
    await tester.pumpWidget(
      fixture.scene(
        decoration: const BoxDecoration(
          color: Color(0xff33aaee),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(2), topRight: Radius.circular(6)),
        ),
      ),
    );
    await fixture.finish(tester);
    final values = fixture.values;
    expect(
      (
        values['boxGaussianMeshPaintCount'],
        values['firstPresentationHasContour'],
        values['captureCount'],
        (values['boxGaussianNativePaintCount']! as int) > 0,
      ),
      (
        0,
        true,
        0,
        true,
      ),
    );
  });

  testWidgets('when a corner radius exceeds five sigmas, it should retain the complete native shadow', (tester) async {
    await tester.pumpWidget(
      fixture.scene(
        amount: 0,
        size: const Size.square(200),
        decoration: const BoxDecoration(color: Color(0xff33aaee), shape: BoxShape.circle),
      ),
    );
    await fixture.finish(tester);
    final values = fixture.values;
    expect(
      (
        values['boxGaussianMeshPaintCount'],
        values['firstPresentationHasContour'],
        values['captureCount'],
        (values['boxGaussianNativePaintCount']! as int) > 0,
      ),
      (
        0,
        true,
        0,
        true,
      ),
    );
  });

  testWidgets(
    'when a shadow declares a wide-gamut color space, it should retain native color handling',
    (tester) async {
      await tester.pumpWidget(
        fixture.scene(
          shadows: const [
            Shadow(
              color: Color.from(alpha: .2, red: 0, green: 0, blue: 0, colorSpace: ui.ColorSpace.displayP3),
              blurRadius: 20,
            ),
          ],
        ),
      );
      await fixture.finish(tester);
      final values = fixture.values;
      expect(
        (
          values['boxGaussianMeshPaintCount'],
          values['firstPresentationHasContour'],
          values['captureCount'],
        ),
        (
          0,
          true,
          0,
        ),
      );
    },
  );

  testWidgets('when no known box exists, it should leave Gaussian meshes unused', (tester) async {
    await tester.pumpWidget(
      fixture.scene(
        content: Contour(
          color: const Color(0xffffffff),
          key: fixture.key,
          shadows: const [Shadow(color: Color(0x33000000), blurRadius: 20)],
          child: const Text('Gaussian'),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    final values = fixture.values;
    expect(
      values['boxGaussianMeshPaintCount'],
      0,
    );
  });

  testWidgets(
    'when an ancestor scale raises physical sigma into range, it should paint the qualified mesh immediately',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        fixture.scene(
          transform: Matrix4.diagonal3Values(2, 2, 1),
          shadows: const [Shadow(color: Color(0x33000000), blurRadius: 8)],
        ),
      );
      final values = fixture.values;
      expect(
        (
          values['boxGaussianMeshPaintCount'],
          values['firstPresentationHasContour'],
          values['captureCount'],
          values['boxGaussianNativePaintCount'],
        ),
        (
          1,
          true,
          0,
          0,
        ),
      );
    },
  );

  testWidgets(
    'when a positive uniform ancestor scale keeps physical sigma qualified, it should paint the qualified mesh immediately',
    (
      tester,
    ) async {
      await tester.pumpWidget(fixture.scene(transform: Matrix4.diagonal3Values(.75, .75, 1)));
      final values = fixture.values;
      expect(
        (
          values['boxGaussianMeshPaintCount'],
          values['firstPresentationHasContour'],
          values['captureCount'],
          values['boxGaussianNativePaintCount'],
        ),
        (
          1,
          true,
          0,
          0,
        ),
      );
    },
  );

  testWidgets('when an ancestor scale is nonuniform, it should retain the complete native shadow', (
    tester,
  ) async {
    await tester.pumpWidget(fixture.scene(transform: Matrix4.diagonal3Values(.75, 1, 1)));
    await fixture.finish(tester);
    final values = fixture.values;
    expect(
      (
        values['boxGaussianMeshPaintCount'],
        values['firstPresentationHasContour'],
        values['captureCount'],
        (values['boxGaussianNativePaintCount']! as int) > 0,
      ),
      (
        0,
        true,
        0,
        true,
      ),
    );
  });

  testWidgets(
    'when two eligible shadows have different offsets and alpha, it should match independent mesh owners outside the backing',
    (tester) async {
      const shadows = [
        Shadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(-3, 2)),
        Shadow(color: Color(0x1a000000), blurRadius: 14, offset: Offset(5, -1)),
      ];
      await tester.pumpWidget(fixture.scene(shadows: shadows));
      await fixture.finish(tester);
      final actual = await fixture.pixels(tester);
      await tester.pumpWidget(const SizedBox.shrink());
      Widget surface(Shadow shadow) => Contour(
        color: const Color(0xffffffff),
        amount: 4,
        shadows: [shadow],
        child: Container(
          width: 32,
          height: 30,
          decoration: const BoxDecoration(color: Color(0xff33aaee), borderRadius: BorderRadius.all(Radius.circular(6))),
        ),
      );
      await tester.pumpWidget(
        fixture.scene(
          content: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [for (final shadow in shadows) surface(shadow)],
          ),
        ),
      );
      await tester.pump();
      final expected = await fixture.pixels(tester);
      var maxDifference = 0;
      for (var y = 0; y < 300; y++) {
        for (var x = 0; x < 400; x++) {
          final qx = (x + .5 - 200).abs() - 10;
          final qy = (y + .5 - 150).abs() - 9;
          final distance =
              math.sqrt(math.pow(math.max(qx, 0), 2) + math.pow(math.max(qy, 0), 2)) +
              math.min(math.max(qx, qy), 0) -
              10;
          if (distance < 1) continue;
          for (var channel = 0; channel < 4; channel++) {
            final i = (y * 400 + x) * 4 + channel;
            maxDifference = math.max(maxDifference, (actual[i] - expected[i]).abs());
          }
        }
      }
      expect(maxDifference, 0);
    },
  );

  testWidgets(
    'when a visible scene adds an eligible blur, it should preserve its complete presentation immediately',
    (tester) async {
      await tester.pumpWidget(fixture.scene(shadows: const []));
      await tester.pumpWidget(fixture.scene());
      final values = fixture.values;
      expect(
        (
          values['lastMainCompositionHasContent'],
          values['firstPresentationHasContour'],
          values['boxGaussianMeshPaintCount'],
          values['boxGaussianNativePaintCount'],
          values['captureCount'],
        ),
        (
          true,
          true,
          1,
          0,
          0,
        ),
      );
    },
  );
}
