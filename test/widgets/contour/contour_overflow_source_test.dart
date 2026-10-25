import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'contour_frame_test_binding.dart';
import 'contour_painted_overflow_test_widget.dart';

void main() {
  final binding = ContourFrameTestBinding();

  tearDown(() {
    binding.resetCapture();
    binding.platformDispatcher.views.single
      ..resetDevicePixelRatio()
      ..resetPhysicalSize();
  });

  Object? value(GlobalKey key, String name) => key.currentContext!
      .findRenderObject()!
      .toDiagnosticsNode()
      .getProperties()
      .firstWhere((p) => p.name == name)
      .value;

  Widget scene(
    GlobalKey key,
    AlignmentGeometry alignment,
    TextDirection direction, {
    bool unsafe = false,
    OverflowBoxFit fit = OverflowBoxFit.deferToChild,
    Size wrapperSize = const Size(20, 20),
    Size childSize = const Size(40, 30),
    bool unbounded = false,
  }) {
    Widget source = SizedBox.fromSize(
      size: childSize,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: DecoratedBox(decoration: BoxDecoration(color: Color(0xffff3050))),
      ),
    );
    source = unsafe
        ? ContourPaintedOverflowTestWidget(child: source)
        : OverflowBox(
            alignment: alignment,
            fit: fit,
            minWidth: childSize.width,
            maxWidth: childSize.width,
            minHeight: childSize.height,
            maxHeight: childSize.height,
            child: source,
          );
    Widget content = Contour(
      key: key,
      color: const Color(0xff102060),
      amount: 2,
      child: unbounded ? source : SizedBox.fromSize(size: wrapperSize, child: source),
    );
    if (unbounded) content = Column(mainAxisSize: MainAxisSize.min, children: [content]);
    return Directionality(
      textDirection: direction,
      child: Center(child: content),
    );
  }

  Future<Uint8List> oracle(WidgetTester tester) async {
    final painter = tester.renderObject<RenderDecoratedBox>(
      find.byType(DecoratedBox),
    );
    final contour = tester.renderObject<RenderProxyBox>(find.byType(Contour));
    final source = Path()..addRect(Offset.zero & painter.size);
    final path = source.transform(
      painter.getTransformTo(contour.child).storage,
    );
    final origin = contour.localToGlobal(Offset.zero);
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..save()
      ..translate(origin.dx, origin.dy)
      ..drawRRect(
        RRect.fromRectAndRadius(path.getBounds().inflate(2), const Radius.circular(2)),
        Paint()..color = const Color(0xff102060),
      )
      ..restore()
      ..save()
      ..transform(painter.getTransformTo(null).storage)
      ..drawRect(Offset.zero & painter.size, Paint()..color = const Color(0xffff3050))
      ..restore();
    final picture = recorder.endRecording();
    final image = await tester.runAsync(() => picture.toImage(100, 100));
    try {
      final data = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      return Uint8List.fromList(data!.buffer.asUint8List());
    } finally {
      image!.dispose();
      picture.dispose();
    }
  }

  Future<void> reset(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 35)),
    );
  }

  for (final fit in OverflowBoxFit.values) {
    for (final direction in TextDirection.values) {
      for (final alignment in [
        Alignment.topLeft,
        Alignment.center,
        Alignment.bottomRight,
        AlignmentDirectional.centerStart,
      ]) {
        testWidgets(
          'when $fit overflows at $alignment in $direction, it should pair exact first-scene geometry without capture or worker starts',
          (tester) async {
            tester.view
              ..devicePixelRatio = 1
              ..physicalSize = const Size.square(100);
            final key = GlobalKey();
            binding.captureNextFrame();
            await tester.pumpWidget(scene(key, alignment, direction, fit: fit));
            final actual = await binding.pixels(tester);
            final expected = await oracle(tester);
            final result = (
              value(key, 'declaredPathActive'),
              value(key, 'captureCount'),
              value(key, 'traceNativeStarts'),
              listEquals(actual, expected),
            );
            await reset(tester);
            expect(result, (true, 0, 0, true));
          },
        );
      }
    }
    testWidgets(
      'when a zero-sized $fit wrapper has a visible overflowing child, it should pair that child and exact contour without capture',
      (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size.square(100);
        final key = GlobalKey();
        binding.captureNextFrame();
        await tester.pumpWidget(
          scene(
            key,
            Alignment.center,
            TextDirection.ltr,
            fit: fit,
            wrapperSize: Size.zero,
          ),
        );
        final actual = await binding.pixels(tester);
        final expected = await oracle(tester);
        final result = (
          value(key, 'declaredPathActive'),
          value(key, 'captureCount'),
          value(key, 'traceNativeStarts'),
          listEquals(actual, expected),
          actual.any((channel) => channel > 0),
        );
        await reset(tester);
        expect(result, (true, 0, 0, true, true));
      },
    );
  }

  testWidgets(
    'when deferToChild receives an unbounded vertical axis, it should pair the finite child geometry without capture',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size.square(100);
      final key = GlobalKey();
      binding.captureNextFrame();
      await tester.pumpWidget(
        scene(key, Alignment.center, TextDirection.ltr, unbounded: true),
      );
      final actual = await binding.pixels(tester);
      final expected = await oracle(tester);
      final result = (
        value(key, 'declaredPathActive'),
        value(key, 'captureCount'),
        value(key, 'traceNativeStarts'),
        listEquals(actual, expected),
      );
      await reset(tester);
      expect(result, (true, 0, 0, true));
    },
  );

  testWidgets(
    'when a known filled box overflows, it should pair its native backing on the first scene without capture or worker starts',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size.square(100);
      final key = GlobalKey();
      binding.captureNextFrame();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: Contour(
              key: key,
              color: const Color(0xff102060),
              amount: 2,
              child: const SizedBox.square(
                dimension: 20,
                child: OverflowBox(
                  minWidth: 40,
                  maxWidth: 40,
                  minHeight: 30,
                  maxHeight: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xffff3050)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final pixels = await binding.pixels(tester);
      List<int> pixel(int x, int y) => pixels.sublist((y * 100 + x) * 4, (y * 100 + x) * 4 + 4);
      final result = (
        value(key, 'declaredPathActive'),
        value(key, 'captureCount'),
        value(key, 'traceNativeStarts'),
        listEquals(pixel(50, 50), [255, 48, 80, 255]),
        listEquals(pixel(29, 50), [16, 32, 96, 255]),
      );
      await reset(tester);
      expect(result, (true, 0, 0, true, true));
    },
  );

  for (final change in [
    (
      name: 'alignment offset',
      beforeAlignment: Alignment.topLeft,
      afterAlignment: Alignment.bottomRight,
      beforeDirection: TextDirection.ltr,
      afterDirection: TextDirection.ltr,
      afterSize: const Size(40, 30),
    ),
    (
      name: 'minimum and maximum constraints',
      beforeAlignment: Alignment.center,
      afterAlignment: Alignment.center,
      beforeDirection: TextDirection.ltr,
      afterDirection: TextDirection.ltr,
      afterSize: const Size(24, 16),
    ),
    (
      name: 'directional alignment after RTL',
      beforeAlignment: AlignmentDirectional.centerStart,
      afterAlignment: AlignmentDirectional.centerStart,
      beforeDirection: TextDirection.ltr,
      afterDirection: TextDirection.rtl,
      afterSize: const Size(40, 30),
    ),
  ]) {
    testWidgets(
      'when ${change.name} changes, it should restore exact box geometry in the following composition without capture',
      (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size.square(100);
        final key = GlobalKey();
        await tester.pumpWidget(
          scene(key, change.beforeAlignment, change.beforeDirection),
        );
        await tester.pumpWidget(
          scene(
            key,
            change.afterAlignment,
            change.afterDirection,
            childSize: change.afterSize,
          ),
        );
        // Existing source preflight presents live content immediately; the next
        // composition restores backing after any supported inner transform changes.
        binding.captureNextFrame();
        await tester.pump();
        final actual = await binding.pixels(tester);
        final expected = await oracle(tester);
        final leaf = tester.renderObject<RenderDecoratedBox>(
          find.byType(DecoratedBox),
        );
        final result = (
          value(key, 'declaredPathActive'),
          value(key, 'captureCount'),
          value(key, 'traceNativeStarts'),
          listEquals(actual, expected),
          Size(leaf.size.width + 4, leaf.size.height + 6),
          tester.getSize(find.byType(Contour)),
        );
        await reset(tester);
        expect(result, (
          true,
          0,
          0,
          true,
          change.afterSize,
          const Size(20, 20),
        ));
      },
    );
  }

  testWidgets(
    'when a subclass paints extra artwork, it should reject declared traversal and use generic tracing',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size.square(100);
      final key = GlobalKey();
      await tester.pumpWidget(
        scene(key, Alignment.center, TextDirection.ltr, unsafe: true),
      );
      final result = value(key, 'declaredPathActive');
      await reset(tester);
      expect(result, false);
    },
  );
}
