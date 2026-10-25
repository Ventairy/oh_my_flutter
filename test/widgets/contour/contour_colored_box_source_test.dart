import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour.dart';

import 'contour_frame_test_binding.dart';

void main() {
  final binding = ContourFrameTestBinding();
  const blue = Color(0xff2070d0);
  const white = Color(0xffffffff);

  Object? diagnostic(GlobalKey key, String name) => key.currentContext!
      .findRenderObject()!
      .toDiagnosticsNode()
      .getProperties()
      .firstWhere((property) => property.name == name)
      .value;

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(ContourProcessorTestHarness.waitForStop);
    await tester.pump();
  }

  tearDown(() {
    binding.resetCapture();
    binding.platformDispatcher.views.single
      ..resetDevicePixelRatio()
      ..resetPhysicalSize();
  });

  Future<Uint8List> oracle(
    WidgetTester tester,
    Iterable<RenderBox> sources, {
    double amount = 3,
    List<Shadow> shadows = const [],
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (final source in sources) {
      final rect = source.localToGlobal(Offset.zero) & source.size;
      final backing = RRect.fromRectAndRadius(rect.inflate(amount), Radius.circular(amount));
      for (final shadow in shadows) {
        canvas.drawRRect(
          backing.shift(shadow.offset),
          Paint()
            ..color = shadow.color
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurSigma),
        );
      }
      canvas
        ..drawRRect(backing, Paint()..color = white)
        ..drawRect(rect, Paint()..color = blue);
    }
    final picture = recorder.endRecording();
    final image = await tester.runAsync(() => picture.toImage(240, 160));
    try {
      final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
      return Uint8List.fromList(data!.buffer.asUint8List());
    } finally {
      image!.dispose();
      picture.dispose();
    }
  }

  for (final container in [false, true]) {
    testWidgets(
      'when forty empty ${container ? 'Container color' : 'ColoredBox'} sources first appear, it should pair exact direct contours without capture or worker starts',
      (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(240, 160);
        final keys = List.generate(40, (_) => GlobalKey());
        final sourceKeys = List.generate(40, (_) => GlobalKey());
        final starts = ContourProcessorTestHarness.starts;
        binding.captureNextFrame(size: const Size(240, 160));
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var index = 0; index < 40; index++)
                      Contour(
                        key: keys[index],
                        color: white,
                        amount: 3,
                        child: container
                            ? Container(key: sourceKeys[index], width: 20, height: 14, color: blue)
                            : SizedBox(
                                width: 20,
                                height: 14,
                                child: ColoredBox(key: sourceKeys[index], color: blue),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        final pixels = await binding.pixels(tester);
        final expected = await oracle(
          tester,
          sourceKeys.map((key) => key.currentContext!.findRenderObject()! as RenderBox),
        );
        final result = (
          keys.where((key) => diagnostic(key, 'knownBoxFillActive') == true).length,
          keys.where((key) => diagnostic(key, 'firstPresentationHasContour') == true).length,
          keys.fold<int>(0, (sum, key) => sum + (diagnostic(key, 'captureCount')! as int)),
          ContourProcessorTestHarness.starts - starts,
          listEquals(pixels, expected),
        );
        await unmount(tester);
        expect(result, (40, 40, 0, 0, true));
      },
    );
  }

  testWidgets(
    'when reused constant ColoredBox widgets have different owner sizes, it should bind each actual element and pair all first-frame pixels',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(240, 160);
      const shared = ColoredBox(color: blue);
      final keys = List.generate(40, (_) => GlobalKey());
      final starts = ContourProcessorTestHarness.starts;
      binding.captureNextFrame(size: const Size(240, 160));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var index = 0; index < 40; index++)
                    Contour(
                      key: keys[index],
                      color: white,
                      amount: 3,
                      child: index.isEven
                          ? SizedBox(width: 14 + index % 5 * 2, height: 9 + index % 3 * 2, child: shared)
                          : SizedBox(
                              width: 14 + index % 5 * 2,
                              height: 9 + index % 3 * 2,
                              child: Container(color: blue, padding: const EdgeInsets.all(1)),
                            ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      final pixels = await binding.pixels(tester);
      final expected = await oracle(tester, tester.renderObjectList<RenderBox>(find.byType(ColoredBox)));
      final result = (
        keys.where((key) => diagnostic(key, 'knownBoxFillActive') == true).length,
        keys.where((key) => diagnostic(key, 'firstPresentationHasContour') == true).length,
        keys.fold<int>(0, (sum, key) => sum + (diagnostic(key, 'captureCount')! as int)),
        ContourProcessorTestHarness.starts - starts,
        listEquals(pixels, expected),
      );
      await unmount(tester);
      expect(result, (40, 40, 0, 0, true));
    },
  );

  Widget single(GlobalKey contour, Widget child, {double amount = 3, List<Shadow> shadows = const []}) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Contour(key: contour, color: white, amount: amount, shadows: shadows, child: child),
        ),
      );

  testWidgets(
    'when a ColoredBox has an ordinary shadow, it should pair exact native fill and shadow on its first submitted frame',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(240, 160);
      final key = GlobalKey();
      const shadows = [Shadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(2, 3))];
      final starts = ContourProcessorTestHarness.starts;
      binding.captureNextFrame(size: const Size(240, 160));
      await tester.pumpWidget(
        single(
          key,
          const SizedBox(width: 20, height: 14, child: ColoredBox(color: blue)),
          shadows: shadows,
        ),
      );
      final actual = await binding.pixels(tester);
      final expected = await oracle(
        tester,
        tester.renderObjectList<RenderBox>(find.byType(ColoredBox)),
        shadows: shadows,
      );
      final result = (
        diagnostic(key, 'knownBoxFillActive'),
        diagnostic(key, 'firstPresentationHasContour'),
        diagnostic(key, 'captureCount'),
        ContourProcessorTestHarness.starts - starts,
        listEquals(actual, expected),
      );
      await unmount(tester);
      expect(result, (true, true, 0, 0, true));
    },
  );

  testWidgets(
    'when ColoredBox size and amount change, it should retain its renderer and paint the new native backing in the same frame',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(240, 160);
      final key = GlobalKey();
      final source = GlobalKey();
      await tester.pumpWidget(
        single(
          key,
          SizedBox(
            width: 20,
            height: 14,
            child: ColoredBox(key: source, color: blue),
          ),
        ),
      );
      final before = source.currentContext!.findRenderObject();
      binding.captureNextFrame(size: const Size(240, 160));
      await tester.pumpWidget(
        single(
          key,
          SizedBox(
            width: 32,
            height: 18,
            child: ColoredBox(key: source, color: blue),
          ),
          amount: 5,
        ),
      );
      final actual = await binding.pixels(tester);
      final expected = await oracle(tester, [source.currentContext!.findRenderObject()! as RenderBox], amount: 5);
      final result = (
        identical(before, source.currentContext!.findRenderObject()),
        diagnostic(key, 'knownBoxFillActive'),
        diagnostic(key, 'captureCount'),
        listEquals(actual, expected),
      );
      await unmount(tester);
      expect(result, (true, true, 0, true));
    },
  );

  for (final faint in [const Color(0x002070d0), const Color(0x802070d0)]) {
    testWidgets(
      'when a retained ColoredBox changes only its descendant color to ${faint.a}, it should hide its stale backing in the first scene',
      (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(240, 160);
        final value = ValueNotifier(blue);
        addTearDown(value.dispose);
        final key = GlobalKey();
        final source = GlobalKey();
        await tester.pumpWidget(
          single(
            key,
            ValueListenableBuilder<Color>(
              valueListenable: value,
              builder: (context, color, child) => SizedBox(
                width: 20,
                height: 14,
                child: ColoredBox(key: source, color: color),
              ),
            ),
          ),
        );
        final contourBefore = key.currentContext!.findRenderObject();
        final sourceBefore = source.currentContext!.findRenderObject();
        value.value = faint;
        binding.captureNextFrame(size: const Size(240, 160));
        await tester.pump();
        final actual = await binding.pixels(tester);
        const border = (80 * 240 + 108) * 4;
        final result = (
          identical(contourBefore, key.currentContext!.findRenderObject()),
          identical(sourceBefore, source.currentContext!.findRenderObject()),
          diagnostic(key, 'knownBoxFillActive'),
          (actual[border], actual[border + 1], actual[border + 2], actual[border + 3]),
        );
        await unmount(tester);
        expect(result, (true, true, false, (0, 0, 0, 0)));
      },
    );
  }

  testWidgets(
    'when a retained ColoredBox disables only antialiasing, it should reject stale metadata in the first scene',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(240, 160);
      final antialias = ValueNotifier(true);
      addTearDown(antialias.dispose);
      final key = GlobalKey();
      final source = GlobalKey();
      await tester.pumpWidget(
        single(
          key,
          ValueListenableBuilder<bool>(
            valueListenable: antialias,
            builder: (context, value, child) => SizedBox(
              width: 20,
              height: 14,
              child: ColoredBox(key: source, color: blue, isAntiAlias: value),
            ),
          ),
        ),
      );
      final sourceBefore = source.currentContext!.findRenderObject();
      antialias.value = false;
      binding.captureNextFrame(size: const Size(240, 160));
      await tester.pump();
      final actual = await binding.pixels(tester);
      const border = (80 * 240 + 108) * 4;
      final result = (
        identical(sourceBefore, source.currentContext!.findRenderObject()),
        diagnostic(key, 'knownBoxFillActive'),
        (actual[border], actual[border + 1], actual[border + 2], actual[border + 3]),
      );
      await unmount(tester);
      expect(result, (true, false, (0, 0, 0, 0)));
    },
  );

  testWidgets(
    'when keyed ColoredBox elements move between contour owners, it should resolve current identities and pair exact first-scene pixels',
    (tester) async {
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(240, 160);
      final contours = [GlobalKey(), GlobalKey()];
      final sources = [GlobalKey(), GlobalKey()];
      Widget scene({required bool swap}) => Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            for (var index = 0; index < 2; index++)
              SizedBox(
                width: 120,
                height: 160,
                child: Center(
                  child: Contour(
                    key: contours[index],
                    color: white,
                    amount: 3,
                    child: SizedBox(
                      width: 20 + index * 10,
                      height: 14 + index * 4,
                      child: ColoredBox(key: sources[swap ? 1 - index : index], color: blue),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
      await tester.pumpWidget(scene(swap: false));
      final before = sources.map((key) => key.currentContext!.findRenderObject()).toList();
      binding.captureNextFrame(size: const Size(240, 160));
      await tester.pumpWidget(scene(swap: true));
      final actual = await binding.pixels(tester);
      final expected = await oracle(tester, sources.map((key) => key.currentContext!.findRenderObject()! as RenderBox));
      final result = (
        sources.indexed.every((entry) => identical(before[entry.$1], entry.$2.currentContext!.findRenderObject())),
        contours.every((key) => diagnostic(key, 'knownBoxFillActive') == true),
        contours.fold<int>(0, (sum, key) => sum + (diagnostic(key, 'captureCount')! as int)),
        listEquals(actual, expected),
      );
      await unmount(tester);
      expect(result, (true, true, 0, true));
    },
  );
}
