import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';

import 'morph_gesture_start/gesture_start_scene.dart';

void main() {
  for (final reversing in [false, true]) {
    late GestureStartScene scene;
    unawaited(
      goldenTest(
        'when ${reversing ? 'a swipe first reverses toward cancellation' : 'a swipe first moves'}, it should keep the shared element at its settled position',
        fileName: 'morph_gesture_${reversing ? 'reversing' : 'first_frame'}',
        constraints: const BoxConstraints.tightFor(width: 400, height: 700),
        builder: () {
          scene = GestureStartScene();
          return scene.app;
        },
        whilePerforming: (tester) async {
          scene.push();
          await tester.pumpAndSettle();
          final gesture = await tester.startGesture(const Offset(1, 350));
          await gesture.moveBy(const Offset(20, 0));
          await tester.pump();
          if (reversing) {
            await gesture.moveBy(const Offset(80, 0));
            await tester.pump();
            await gesture.moveBy(const Offset(-40, 0));
            await tester.pump();
          }
          return () async {
            await gesture.cancel();
            await tester.pumpAndSettle();
          };
        },
      ),
    );
  }
}
