import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

Widget _testApp({required Widget child}) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('MotionController', () {
    test('when unattached, it should ignore play', () {
      final controller = MotionController();

      expect(controller.play, returnsNormally);
    });

    testWidgets(
      'when shared by mounted motions, it should replay all of them',
      (tester) async {
        final controller = MotionController();
        final events = <String>[];
        await tester.pumpWidget(
          _testApp(
            child: Row(
              children: [
                Motion(
                  controller: controller,
                  effect: FadeInMotionEffect(
                    duration: const Duration(milliseconds: 100),
                    onStart: () => events.add('first'),
                  ),
                  child: const SizedBox(width: 40, height: 20),
                ),
                Motion(
                  controller: controller,
                  effect: FadeInMotionEffect(
                    duration: const Duration(milliseconds: 100),
                    onStart: () => events.add('second'),
                  ),
                  child: const SizedBox(width: 40, height: 20),
                ),
              ],
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        events.clear();

        controller.play();
        await tester.pump();

        expect(events, ['first', 'second']);
      },
    );

    testWidgets(
      'when the controller changes, it should detach the old controller',
      (tester) async {
        final oldController = MotionController();
        final newController = MotionController();
        late StateSetter rebuild;
        var controller = oldController;
        var starts = 0;
        await tester.pumpWidget(
          _testApp(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Motion(
                  controller: controller,
                  effect: FadeInMotionEffect(
                    duration: const Duration(milliseconds: 100),
                    onStart: () => starts += 1,
                  ),
                  child: const SizedBox(width: 40, height: 20),
                );
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        rebuild(() => controller = newController);
        await tester.pump();

        oldController.play();
        await tester.pump();
        final startsAfterOldController = starts;
        newController.play();
        await tester.pump();

        expect((startsAfterOldController, starts), (1, 2));
      },
    );

    testWidgets(
      'when its motion is disposed, it should ignore play',
      (tester) async {
        final controller = MotionController();
        await tester.pumpWidget(
          _testApp(
            child: Motion(
              controller: controller,
              effect: const FadeInMotionEffect(),
              child: const SizedBox(width: 40, height: 20),
            ),
          ),
        );
        await tester.pumpWidget(_testApp(child: const SizedBox.shrink()));

        expect(controller.play, returnsNormally);
      },
    );
  });
}
