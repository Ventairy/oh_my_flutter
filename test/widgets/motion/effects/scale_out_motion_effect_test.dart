import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

abstract final class ScaleOutMotionEffectTestHelpers {
  static const childKey = Key('scale_out_child');

  static Widget app({required Widget child}) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  static double scale(WidgetTester tester) {
    final child = tester.renderObject<RenderBox>(find.byKey(childKey));
    final left = child.localToGlobal(Offset.zero).dx;
    final right = child.localToGlobal(Offset(child.size.width, 0)).dx;
    return (right - left) / child.size.width;
  }

  static T textMotionProperty<T>(WidgetTester tester, {required String name}) {
    final renderObject = tester.renderObject<RenderObject>(
      find.descendant(
        of: find.byType(TextMotion),
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_OptimizedTextMotion',
        ),
      ),
    );
    final property = renderObject.toDiagnosticsNode().getProperties().singleWhere(
      (property) => property.name == name,
    );
    final value = (property as DiagnosticsProperty<T>).value;
    if (value == null) {
      throw StateError('TextMotion diagnostic $name is null.');
    }
    return value;
  }
}

void main() {
  group('ScaleOutMotionEffect', () {
    testWidgets('when using defaults, it should scale from the child size to zero', (tester) async {
      await tester.pumpWidget(
        ScaleOutMotionEffectTestHelpers.app(
          child: const Motion(
            effect: ScaleOutMotionEffect(),
            child: SizedBox(
              key: ScaleOutMotionEffectTestHelpers.childKey,
              width: 40,
              height: 20,
            ),
          ),
        ),
      );
      final start = ScaleOutMotionEffectTestHelpers.scale(tester);
      await tester.pump(const Duration(milliseconds: 150));
      final middle = ScaleOutMotionEffectTestHelpers.scale(tester);
      await tester.pump(const Duration(milliseconds: 150));
      final end = ScaleOutMotionEffectTestHelpers.scale(tester);

      expect((start, middle, end), (1, 0.5, 0));
    });

    test('when configured, it should expose the requested motion values', () {
      const effect = ScaleOutMotionEffect(
        scale: 0.4,
        delay: Duration(milliseconds: 100),
        duration: Duration(milliseconds: 500),
        curve: Curves.easeIn,
        playback: MotionPlayback.loop,
      );

      expect(
        (effect.scale, effect.delay, effect.duration, effect.curve, effect.playback),
        (0.4, const Duration(milliseconds: 100), const Duration(milliseconds: 500), Curves.easeIn, MotionPlayback.loop),
      );
    });

    testWidgets('when using an ease-in-back curve, it should expand before scaling down', (tester) async {
      await tester.pumpWidget(
        ScaleOutMotionEffectTestHelpers.app(
          child: const Motion(
            effect: ScaleOutMotionEffect(
              scale: 0.65,
              duration: Duration(milliseconds: 350),
              curve: Curves.easeInBack,
            ),
            child: SizedBox(
              key: ScaleOutMotionEffectTestHelpers.childKey,
              width: 40,
              height: 20,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(ScaleOutMotionEffectTestHelpers.scale(tester), greaterThan(1));
    });

    testWidgets('when scaling, it should preserve the child layout size', (tester) async {
      await tester.pumpWidget(
        ScaleOutMotionEffectTestHelpers.app(
          child: const Motion(
            effect: ScaleOutMotionEffect(),
            child: SizedBox(
              key: ScaleOutMotionEffectTestHelpers.childKey,
              width: 40,
              height: 20,
            ),
          ),
        ),
      );
      final initialSize = tester.getSize(find.byKey(ScaleOutMotionEffectTestHelpers.childKey));
      await tester.pump(const Duration(milliseconds: 150));

      expect(
        (initialSize, tester.getSize(find.byKey(ScaleOutMotionEffectTestHelpers.childKey))),
        (const Size(40, 20), const Size(40, 20)),
      );
    });

    testWidgets('when applied to text, it should scale every grapheme to the configured size', (tester) async {
      await tester.pumpWidget(
        ScaleOutMotionEffectTestHelpers.app(
          child: const TextMotion(
            effect: ScaleOutMotionEffect(scale: 0.4),
            stagger: Duration.zero,
            child: Text('AB'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        ScaleOutMotionEffectTestHelpers.textMotionProperty<Iterable<double>>(
          tester,
          name: 'characterScales',
        ).toList(),
        <double>[0.4, 0.4],
      );
    });

    test('when scale is not finite, it should reject the configuration', () {
      expect(
        () => ScaleOutMotionEffect(scale: double.infinity),
        throwsAssertionError,
      );
    });
  });
}
