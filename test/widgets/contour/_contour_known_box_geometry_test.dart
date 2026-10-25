import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour.dart';

import 'contour_test_painter.dart';

void main() {
  const red = Color(0xffff0000);
  const white = Color(0xffffffff);
  Widget scene(
    GlobalKey boundary,
    GlobalKey contour,
    BoxDecoration decoration, {
    Size size = const Size(40, 30),
    double amount = 4,
    double scaleX = 1,
    double scaleY = 1,
    List<Shadow> shadows = const [],
    Color color = white,
    Widget Function(Widget child)? wrap,
  }) {
    Widget child = SizedBox.fromSize(
      size: size,
      child: DecoratedBox(decoration: decoration),
    );
    if (scaleX != 1 || scaleY != 1) {
      child = Transform.scale(scaleX: scaleX, scaleY: scaleY, alignment: Alignment.center, child: child);
    }
    if (wrap != null) child = wrap(child);
    return MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 3),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: boundary,
            child: SizedBox(
              width: 160,
              height: 140,
              child: Center(
                child: Contour(key: contour, color: color, amount: amount, shadows: shadows, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Object? diagnostic(GlobalKey key, String name) => key.currentContext!
      .findRenderObject()!
      .toDiagnosticsNode()
      .getProperties()
      .where((property) => property.name == name)
      .firstOrNull
      ?.value;

  Future<Uint8List> pixels(WidgetTester tester, GlobalKey key) async {
    final image = await tester.runAsync(
      () => (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 3),
    );
    try {
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
      return bytes!.buffer.asUint8List();
    } finally {
      image!.dispose();
    }
  }

  testWidgets('when a small circle expands beyond its diameter, it should fill the complete enlarged disk', (
    tester,
  ) async {
    final boundary = GlobalKey();
    final contour = GlobalKey();
    await tester.pumpWidget(
      scene(
        boundary,
        contour,
        const BoxDecoration(color: red, shape: BoxShape.circle),
        size: const Size(8, 8),
        amount: 20,
      ),
    );
    final bytes = await pixels(tester, boundary);
    const index = ((70 * 3) * (160 * 3) + (92 * 3)) * 4;
    expect(bytes.sublist(index, index + 4), [255, 255, 255, 255]);
  });

  final shapes = <String, BoxDecoration>{
    'rect': const BoxDecoration(color: red),
    'circle': const BoxDecoration(color: red, shape: BoxShape.circle),
    'circular rounded rect': const BoxDecoration(color: red, borderRadius: BorderRadius.all(Radius.circular(8))),
    'unequal circular corners': const BoxDecoration(
      color: red,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(7),
        topRight: Radius.circular(2),
        bottomLeft: Radius.circular(11),
      ),
    ),
    'oversized circular corners': const BoxDecoration(color: red, borderRadius: BorderRadius.all(Radius.circular(80))),
  };
  for (final entry in shapes.entries) {
    testWidgets(
      'when ${entry.key} is a known opaque leaf, it should present direct fill on the initial frame without capture or worker',
      (tester) async {
        final boundary = GlobalKey();
        final contour = GlobalKey();
        final before = ContourProcessorTestHarness.starts;
        await tester.pumpWidget(scene(boundary, contour, entry.value));
        expect(
          (
            diagnostic(contour, 'knownBoxFillActive'),
            diagnostic(contour, 'firstPresentationHasContour'),
            diagnostic(contour, 'captureCount'),
            ContourProcessorTestHarness.starts - before,
          ),
          (true, true, 0, 0),
        );
      },
    );
  }

  testWidgets('when a known rounded leaf has positive uniform scale, it should retain direct fill', (tester) async {
    final boundary = GlobalKey();
    final contour = GlobalKey();
    await tester.pumpWidget(scene(boundary, contour, shapes['circular rounded rect']!, scaleX: 1.5, scaleY: 1.5));
    expect(diagnostic(contour, 'knownBoxFillActive'), true);
  });

  testWidgets('when a known rounded leaf has nonuniform scale, it should retain the ordinary declared path', (
    tester,
  ) async {
    final boundary = GlobalKey();
    final contour = GlobalKey();
    await tester.pumpWidget(scene(boundary, contour, shapes['circular rounded rect']!, scaleX: 1.5, scaleY: 1.25));
    expect((diagnostic(contour, 'knownBoxFillActive'), diagnostic(contour, 'declaredPathActive')), (false, true));
  });

  testWidgets('when rounded corners are elliptical, it should retain the ordinary declared path', (tester) async {
    final boundary = GlobalKey();
    final contour = GlobalKey();
    await tester.pumpWidget(
      scene(
        boundary,
        contour,
        const BoxDecoration(color: red, borderRadius: BorderRadius.all(Radius.elliptical(6, 10))),
      ),
    );
    expect((diagnostic(contour, 'knownBoxFillActive'), diagnostic(contour, 'declaredPathActive')), (false, true));
  });

  testWidgets('when amount changes on a known circle, it should paint the new complete disk in the same frame', (
    tester,
  ) async {
    final boundary = GlobalKey();
    final contour = GlobalKey();
    await tester.pumpWidget(
      scene(
        boundary,
        contour,
        const BoxDecoration(color: red, shape: BoxShape.circle),
        size: const Size(8, 8),
        amount: 1,
      ),
    );
    await tester.pumpWidget(
      scene(
        boundary,
        contour,
        const BoxDecoration(color: red, shape: BoxShape.circle),
        size: const Size(8, 8),
        amount: 20,
      ),
    );
    final bytes = await pixels(tester, boundary);
    const index = ((70 * 3) * (160 * 3) + (92 * 3)) * 4;
    expect(
      (diagnostic(contour, 'knownBoxFillActive'), bytes[index], bytes[index + 1], bytes[index + 2], bytes[index + 3]),
      (true, 255, 255, 255, 255),
    );
  });
  testWidgets(
    'when unequal oversized circular corners expand, it should normalize the source radii before expansion',
    (tester) async {
      final boundary = GlobalKey();
      final contour = GlobalKey();
      await tester.pumpWidget(
        scene(
          boundary,
          contour,
          const BoxDecoration(
            color: red,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(80),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(10),
              bottomRight: Radius.circular(40),
            ),
          ),
          amount: 20,
        ),
      );
      final bytes = await pixels(tester, boundary);
      const index = ((58 * 3) * (160 * 3) + (49 * 3)) * 4;
      expect(bytes.sublist(index, index + 4), [255, 255, 255, 255]);
    },
  );

  testWidgets(
    'when a known circle has a blurred shadow, it should present its full backing on the initial frame without a shadow image job',
    (tester) async {
      final boundary = GlobalKey();
      final contour = GlobalKey();
      await tester.pumpWidget(
        scene(
          boundary,
          contour,
          const BoxDecoration(color: red, shape: BoxShape.circle),
          size: const Size(8, 8),
          amount: 20,
          shadows: const [Shadow(color: Color(0x996734bd), offset: Offset(0, 3), blurRadius: 6)],
        ),
      );
      expect(
        (
          diagnostic(contour, 'firstPresentationHasContour'),
          diagnostic(contour, 'captureCount'),
          diagnostic(contour, 'shadowCacheBuildCount'),
          diagnostic(contour, 'shadowAtlasBuildCount'),
          diagnostic(contour, 'generating'),
        ),
        (true, 0, 0, 0, false),
      );
    },
  );
  const wideGamutShadow = Shadow(
    color: Color.from(alpha: .3, red: .6, green: .2, blue: .8, colorSpace: ui.ColorSpace.displayP3),
    blurRadius: 6,
    offset: Offset(0, 3),
  );
  const ordinaryShadow = Shadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3));

  testWidgets(
    'when a visible wide gamut shadow wraps a known box, it should retain shadow cache preparation',
    (tester) async {
      final boundary = GlobalKey();
      final contour = GlobalKey();
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(
        scene(
          boundary,
          contour,
          const BoxDecoration(color: red, shape: BoxShape.circle),
          shadows: const [wideGamutShadow],
        ),
      );
      expect(diagnostic(contour, 'generating'), true);
    },
  );

  testWidgets(
    'when mixed visible sRGB and wide gamut shadows wrap a known box, it should retain shadow cache preparation',
    (tester) async {
      final boundary = GlobalKey();
      final contour = GlobalKey();
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(
        scene(
          boundary,
          contour,
          const BoxDecoration(color: red, shape: BoxShape.circle),
          shadows: const [ordinaryShadow, wideGamutShadow],
        ),
      );
      expect(diagnostic(contour, 'generating'), true);
    },
  );

  testWidgets(
    'when a wide gamut shadow is invisible, it should prepare no redundant shadow image for the visible direct shadow',
    (tester) async {
      final boundary = GlobalKey();
      final contour = GlobalKey();
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      await tester.pumpWidget(
        scene(
          boundary,
          contour,
          const BoxDecoration(color: red, shape: BoxShape.circle),
          shadows: const [
            ordinaryShadow,
            Shadow(color: Color.from(alpha: 0, red: .6, green: .2, blue: .8, colorSpace: ui.ColorSpace.displayP3)),
          ],
        ),
      );
      expect(diagnostic(contour, 'generating'), false);
    },
  );
  Widget containerScene(GlobalKey contour, Widget source) => MediaQuery(
    data: const MediaQueryData(devicePixelRatio: 3),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: Contour(
          key: contour,
          color: white,
          amount: 4,
          shadows: const [ordinaryShadow],
          child: source,
        ),
      ),
    ),
  );

  Future<void> stopFallback(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (var attempt = 0; attempt < 200; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump(const Duration(milliseconds: 1));
      if (!ContourProcessorTestHarness.stopping && !ContourProcessorTestHarness.prepared) return;
    }
    throw StateError('Contour fallback worker did not stop.');
  }

  testWidgets(
    'when a genuine sized Container has only its implicit empty padding, it should present the contour immediately without capture or worker',
    (tester) async {
      final contour = GlobalKey();
      final starts = ContourProcessorTestHarness.starts;
      addTearDown(() => stopFallback(tester));
      await tester.pumpWidget(
        containerScene(
          contour,
          Container(width: 32, height: 30, decoration: const BoxDecoration(color: red)),
        ),
      );
      final source = tester.renderObject<RenderDecoratedBox>(find.byType(DecoratedBox));
      expect(
        (
          source.child.runtimeType,
          diagnostic(contour, 'knownBoxFillActive'),
          diagnostic(contour, 'firstPresentationHasContour'),
          diagnostic(contour, 'captureCount'),
          ContourProcessorTestHarness.starts - starts,
          ContourProcessorTestHarness.prepared,
        ),
        (RenderPadding, true, true, 0, 0, false),
      );
    },
  );

  testWidgets(
    'when an externally sized Container has only its implicit empty layout chain, it should present the contour immediately without capture or worker',
    (tester) async {
      final contour = GlobalKey();
      final starts = ContourProcessorTestHarness.starts;
      addTearDown(() => stopFallback(tester));
      await tester.pumpWidget(
        containerScene(
          contour,
          SizedBox(
            width: 32,
            height: 30,
            child: Container(decoration: const BoxDecoration(color: red)),
          ),
        ),
      );
      final source = tester.renderObject<RenderDecoratedBox>(find.byType(DecoratedBox));
      final padding = source.child! as RenderPadding;
      final limited = padding.child! as RenderLimitedBox;
      final constrained = limited.child! as RenderConstrainedBox;
      expect(
        (
          padding.runtimeType,
          limited.runtimeType,
          constrained.runtimeType,
          constrained.child,
          diagnostic(contour, 'knownBoxFillActive'),
          diagnostic(contour, 'captureCount'),
          ContourProcessorTestHarness.starts - starts,
          ContourProcessorTestHarness.prepared,
        ),
        (RenderPadding, RenderLimitedBox, RenderConstrainedBox, null, true, 0, 0, false),
      );
    },
  );

  final paintedChildren = <String, Widget>{
    'painted color': const ColoredBox(color: Color(0xff0000ff)),
    'text content': const Text('Child'),
    'custom painter': const CustomPaint(painter: ContourTestPainter()),
    'semantics': Semantics(label: 'Child', child: const SizedBox.shrink()),
  };
  for (final entry in paintedChildren.entries) {
    testWidgets(
      'when a Container has ${entry.key}, it should retain the ordinary contour path',
      (tester) async {
        final contour = GlobalKey();
        addTearDown(() => stopFallback(tester));
        await tester.pumpWidget(
          containerScene(
            contour,
            Container(
              width: 32,
              height: 30,
              decoration: const BoxDecoration(color: red),
              child: entry.value,
            ),
          ),
        );
        expect(diagnostic(contour, 'knownBoxFillActive'), false);
      },
    );
  }
}
