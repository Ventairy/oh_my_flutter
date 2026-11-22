import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  List<double> packedScales(RenderBox render, TargetPlatform platform, double dpr) {
    final previousPlatform = debugDefaultTargetPlatformOverride;
    final canvas = TestRecordingCanvas();
    try {
      debugDefaultTargetPlatformOverride = platform;
      render.paint(TestRecordingPaintingContext(canvas), Offset.zero);
    } finally {
      debugDefaultTargetPlatformOverride = previousPlatform;
    }

    final scales = <double>[];
    for (final recorded in canvas.invocations) {
      final invocation = recorded.invocation;
      if (invocation.memberName != #drawRawAtlas) continue;
      final paint = invocation.positionalArguments[6] as Paint;
      if (paint.imageFilter != null) continue;
      final transforms = invocation.positionalArguments[1] as Float32List;
      // Sharp glyphs draw directly from the source atlas at its original scale.
      for (var index = 0; index < transforms.length; index += 4) {
        final scale = transforms[index];
        if ((scale - 1 / dpr).abs() > .00001) scales.add(scale);
      }
    }
    return scales;
  }

  setUpAll(() async {
    final loader = FontLoader('PackedFineInter')
      ..addFont(File('test/fixtures/fonts/inter.ttf').readAsBytes().then(ByteData.sublistView));
    await loader.load();
  });

  for (final dpr in [2.0, 3.0]) {
    for (final previousPass in [false, true]) {
      final history = previousPass ? 'following a separable pass' : 'on the first packed frame';
      final kernel = previousPass ? 'reuse the separable kernel' : 'keep the original kernel';
      testWidgets(
        'when Android Skia packs fine blur at DPR $dpr $history, it should $kernel',
        (tester) async {
          tester.view.devicePixelRatio = dpr;
          tester.view.physicalSize = Size(360 * dpr, 150 * dpr);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);

          final controller = MotionController();
          await tester.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: TextMotion(
                  controller: controller,
                  startup: MotionStartup.hold,
                  stagger: const Duration(milliseconds: 4),
                  effect: const _FineBlurReveal(),
                  child: Text(
                    'Sphinx of black quartz, judge my vow. 0123456789',
                    style: TextStyle(
                      fontFamily: 'PackedFineInter',
                      fontSize: 28,
                      // Foreground paint keeps this fixture on the engine filter.
                      foreground: Paint()..color = const Color(0xFF193457),
                    ),
                  ),
                ),
              ),
            ),
          );

          controller.play();
          await tester.pump();
          var elapsed = 0;
          if (previousPass) {
            elapsed = 170;
            await tester.pump(Duration(milliseconds: elapsed));
          }
          await tester.pump(Duration(milliseconds: 400 - elapsed));

          final render = tester.renderObject<RenderBox>(find.byType(TextMotion));
          final stock = packedScales(render, TargetPlatform.linux, dpr);
          final android = packedScales(render, TargetPlatform.android, dpr);
          final scaleRatio = previousPass ? .65 / 1.01 : 1.0;

          expect(android, allOf(isNotEmpty, orderedEquals(stock.map((scale) => closeTo(scale * scaleRatio, .00001)))));
        },
        skip: ui.ImageFilter.isShaderFilterSupported,
      );
    }
  }
}

class _FineBlurReveal extends MotionEffect {
  const new();

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform
      ..fade(.35 + .65 * progress)
      ..blur(4 * (1 - progress));
  }
}
