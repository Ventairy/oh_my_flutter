import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final isMobile = !kIsWeb && (defaultTargetPlatform == .android || defaultTargetPlatform == .iOS);

  for (final (progress, translation, alpha, color) in [
    (0.0, 0.0, 255, const Color(0xFF603020)),
    (0.035, 0.25, 128, const Color(0x80603020)),
  ]) {
    testWidgets('when disintegration is at $progress, it should preserve alpha in native intact cells', (tester) async {
      if (defaultTargetPlatform == .iOS) {
        await tester.runAsync(() async {
          const channel = MethodChannel('dev.ventairy.oh_my_flutter.motion');
          for (var attempt = 0; attempt < 60; attempt++) {
            if (await channel.invokeMethod<bool>('prepareRenderer', const <String, Object?>{}) == true) return;
            await Future<void>.delayed(const Duration(milliseconds: 16));
          }
        });
      }
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      final captureKey = GlobalKey();
      final motionController = MotionController();
      await tester.pumpWidget(
        Directionality(
          textDirection: .ltr,
          child: RepaintBoundary(
            key: captureKey,
            child: Align(
              alignment: .topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Motion(
                  controller: motionController,
                  startup: .hold,
                  effect: _FixedDisintegration(progress: progress, translation: translation),
                  child: ColoredBox(color: color, child: const SizedBox(width: 255, height: 48)),
                ),
              ),
            ),
          ),
        ),
      );
      motionController.play();
      final texture = find.byType(Texture);
      for (var frame = 0; frame < 90 && texture.evaluate().isEmpty; frame++) {
        await tester.pump();
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 16)));
      }
      await tester.pump();
      final boundary = captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final mismatchedPixels = await tester.runAsync(() async {
        final image = await boundary.toImage();
        try {
          final bytes = (await image.toByteData())!;
          var count = 0;
          for (var y = 17; y < 63; y++) {
            for (var x = progress == 0 ? 16 : 120; x < 270; x++) {
              if (bytes.getUint8((y * image.width + x) * 4 + 3) != alpha) count++;
            }
          }
          return count;
        } finally {
          image.dispose();
        }
      });

      expect((texture.evaluate().length, mismatchedPixels), (1, 0));
    }, skip: !isMobile);
  }
}

class _FixedDisintegration extends MotionEffect {
  const new({required this.progress, required this.translation}) : super(duration: const Duration(seconds: 3));

  final double progress;
  final double translation;

  @override
  void apply(double value, MotionEffectTransform transform) {
    transform
      ..translate(x: translation, y: translation)
      ..disintegrate(progress: progress, direction: Offset.zero);
  }
}
