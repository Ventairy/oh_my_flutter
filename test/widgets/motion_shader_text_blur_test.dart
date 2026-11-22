import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  testWidgets(
    'when host text targets Android styling, it should complete playback without a pending timer',
    (tester) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = previousPlatform);

      final controller = MotionController();
      var completions = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextMotion(
            startup: MotionStartup.hold,
            controller: controller,
            stagger: const Duration(milliseconds: 4),
            effect: _Reveal(onEnd: () => completions++),
            child: const Text('Sphinx of black quartz, judge my vow. 0123456789'),
          ),
        ),
      );
      controller.play();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(completions, 1);
    },
    skip: kIsWeb || Platform.isAndroid || ui.ImageFilter.isShaderFilterSupported,
  );
}

class _Reveal extends MotionEffect {
  const new({super.onEnd});

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform
      ..fade(.35 + .65 * progress)
      ..blur(4 * (1 - progress));
  }
}
