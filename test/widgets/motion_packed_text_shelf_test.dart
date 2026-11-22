import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  setUpAll(() async {
    final inter = FontLoader('PackedShelfInter')
      ..addFont(File('test/fixtures/fonts/inter.ttf').readAsBytes().then(ByteData.sublistView));
    await inter.load();
  });

  testWidgets(
    'when narrower atlas rows fit all blurred glyphs, it should draw them in one batch',
    (tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1260, 468);
      addTearDown(() => debugDefaultTargetPlatformOverride = previousPlatform);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = MotionController();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 360,
              child: TextMotion(
                controller: controller,
                startup: MotionStartup.hold,
                stagger: const Duration(milliseconds: 4),
                effect: const _Reveal(),
                child: Text(
                  'Sphinx of black quartz, judge my vow. 0123456789',
                  style: TextStyle(
                    fontFamily: 'PackedShelfInter',
                    fontSize: 28,
                    // Keep this fixture on the cold engine filter path.
                    foreground: Paint()..color = const Color(0xFF193457),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      controller.play();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 232));

      final canvas = TestRecordingCanvas();
      tester.renderObject<RenderBox>(find.byType(TextMotion)).paint(TestRecordingPaintingContext(canvas), Offset.zero);
      final atlasDraws = <({int glyphs, bool withinBudget, bool hasFilter})>[];
      for (final call in canvas.invocations) {
        final invocation = call.invocation;
        if (invocation.memberName != #drawRawAtlas) continue;
        final image = invocation.positionalArguments[0] as ui.Image;
        final transforms = invocation.positionalArguments[1] as Float32List;
        final paint = invocation.positionalArguments[6] as Paint;
        atlasDraws.add((
          glyphs: transforms.length ~/ 4,
          withinBudget: image.width <= 1024 && image.height <= 1024 && image.width * image.height <= 256 * 1024,
          hasFilter: paint.imageFilter != null,
        ));
      }
      expect(atlasDraws, [(glyphs: 41, withinBudget: true, hasFilter: false)]);
    },
    skip: ui.ImageFilter.isShaderFilterSupported,
  );
}

class _Reveal extends MotionEffect {
  const new();

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform
      ..fade(.35 + .65 * progress)
      ..blur(4 * (1 - progress));
  }
}
