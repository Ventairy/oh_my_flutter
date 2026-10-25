@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_source.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_bindings.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_session.dart';

import 'contour_composite_counting_capture.dart';
import 'contour_test_harness.dart';

void main() {
  final boundary = GlobalKey();
  var capturedTiles = 0;
  var capturedPixels = 0;
  late List<ContourController> controllers;

  Widget tree({required bool unshared, required String text, required String family}) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: RepaintBoundary(
        key: boundary,
        child: SizedBox(
          width: 480,
          height: 240,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var index = 0; index < 40; index++)
                Positioned(
                  left: (index % 8) * 60,
                  top: (index ~/ 8) * 48,
                  width: 60,
                  height: 48,
                  child: Center(
                    child: Contour(
                      controller: controllers[index],
                      color: const Color(0xFFFFFFFF),
                      amount: 3,
                      shadows: const [Shadow(color: Color(0x80000000), blurRadius: 2, offset: Offset(0, 2))],
                      child: unshared
                          ? Listener(
                              child: Text(
                                text,
                                style: TextStyle(
                                  fontFamily: family,
                                  fontSize: 20,
                                  height: 1,
                                  color: const Color(0xFF4285F4),
                                ),
                              ),
                            )
                          : Text(
                              text,
                              style: TextStyle(
                                fontFamily: family,
                                fontSize: 20,
                                height: 1,
                                color: const Color(0xFF4285F4),
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
  );

  Future<Uint8List> pixels(WidgetTester tester) async {
    final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await tester.runAsync(render.toImage);
    try {
      final data = await tester.runAsync(() => image!.toByteData());
      return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image!.dispose();
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.idle();
  }

  setUpAll(() async {
    await ui.loadFontFromList(
      File('test/fixtures/fonts/contour_native/contour_mixed_bitmap.ttf').readAsBytesSync(),
      fontFamily: 'ContourPendingBitmapFixture',
    );
  });

  setUp(() {
    capturedTiles = capturedPixels = 0;
    controllers = List.generate(40, (_) => ContourController());
    final real = ContourCompositeSource.shared;
    ContourCompositeSource.testOverride = ContourCompositeCountingCapture(real, (width, height) {
      capturedTiles++;
      capturedPixels += width * height;
    });
  });

  tearDown(() {
    ContourCompositeSource.testOverride = null;
    for (final controller in controllers) {
      controller.dispose();
    }
  });

  for (final (label, text, family) in [
    ('text', 'O', 'Ahem'),
    ('bitmap glyph', 'x', 'ContourPendingBitmapFixture'),
  ]) {
    testWidgets(
      'when forty identical $label decorations share work, it should preserve every screen pixel with one native input tile',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetDevicePixelRatio);
        final nativeBefore = ContourNativePortBindings.stat(18);
        await tester.pumpWidget(tree(unshared: true, text: text, family: family));
        await ContourTestHarness.settle(tester);
        final original = await pixels(tester);
        final oldTiles = capturedTiles;
        final oldPixels = capturedPixels;
        final oldBytes = ContourNativePortBindings.stat(18) - nativeBefore;
        await unmount(tester);
        capturedTiles = capturedPixels = 0;
        final nativeMiddle = ContourNativePortBindings.stat(18);
        await tester.pumpWidget(tree(unshared: false, text: text, family: family));
        await ContourTestHarness.settle(tester);
        final shared = await pixels(tester);
        final newTiles = capturedTiles;
        final newPixels = capturedPixels;
        final newBytes = ContourNativePortBindings.stat(18) - nativeMiddle;
        final allReady = controllers.every((controller) => controller.isReady);
        final allComposite = tester
            .renderObjectList<RenderObject>(find.byType(Contour))
            .every(
              (render) => render.toDiagnosticsNode().getProperties().any(
                (property) => property.name == 'compositeReady' && property.value == true,
              ),
            );
        await unmount(tester);
        expect(
          <Object>[
            oldTiles,
            newTiles,
            oldPixels == newPixels * 40,
            oldBytes == newBytes * 40 && newBytes > 0,
            allReady,
            allComposite,
            shared,
          ],
          <Object>[40, 1, true, true, true, true, original],
        );
      },
      skip: !ContourNativePortSession.isSupported,
    );
  }
}
