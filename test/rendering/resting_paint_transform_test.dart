import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/rendering/resting_paint_transform.dart';
import 'package:oh_my_flutter/src/widgets/motion/motion.dart';

void main() {
  for (final fixture in [
    (
      name: 'scale entrance',
      effect: const ScaleInMotionEffect(
        scale: .65,
        duration: Duration(milliseconds: 100),
      ),
    ),
    (
      name: 'invisible pop',
      effect: const PopMotionEffect(
        scale: .65,
        duration: Duration(milliseconds: 100),
      ),
    ),
  ]) {
    testWidgets(
      'when static rotation and fitted scale surround a held ${fixture.name}, it should preserve their resting transform',
      (tester) async {
        final key = GlobalKey();
        final controller = MotionController();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: .25, top: .375),
                child: SizedBox(
                  width: 80,
                  height: 60,
                  child: FittedBox(
                    child: SizedBox(
                      width: 100,
                      height: 80,
                      child: Transform.rotate(
                        angle: .52,
                        child: Motion(
                          controller: controller,
                          startup: MotionStartup.hold,
                          effect: fixture.effect,
                          child: SizedBox(key: key, width: 40, height: 24),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final source = key.currentContext!.findRenderObject()!;
        final initial = source.getTransformTo(null);
        final resting = RestingPaintTransform.toView(source)!;
        controller.play();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final actual = source.getTransformTo(null);
        expect(
          [
            List.generate(
              16,
              (i) => (actual.storage[i] - resting.storage[i]).abs() < 1e-8,
            ).every((v) => v),
            (initial.storage[0] - actual.storage[0]).abs() > .01,
            actual.storage[1].abs() > .1,
          ],
          [true, true, true],
        );
      },
    );
  }

  testWidgets(
    'when a static transform has no animated capability, it should preserve the entire actual matrix',
    (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: Transform.translate(
              offset: const Offset(.25, .375),
              child: Transform.rotate(
                angle: .52,
                child: Transform.scale(
                  scale: .85,
                  child: SizedBox(key: key, width: 40, height: 24),
                ),
              ),
            ),
          ),
        ),
      );
      final source = key.currentContext!.findRenderObject()!;
      final actual = source.getTransformTo(null);
      final resting = RestingPaintTransform.toView(source)!;
      expect(
        List.generate(
          16,
          (i) => (actual.storage[i] - resting.storage[i]).abs() < 1e-8,
        ).every((v) => v),
        true,
      );
    },
  );
  test('when a render object has no owning view, it should decline the resting transform', () {
    expect(
      RestingPaintTransform.toView(
        RenderConstrainedBox(
          additionalConstraints: const BoxConstraints.tightFor(
            width: 1,
            height: 1,
          ),
        ),
      ),
      isNull,
    );
  });
}
