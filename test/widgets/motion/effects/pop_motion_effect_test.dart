import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

abstract final class PopMotionEffectTestHelpers {
  static const childKey = Key('pop_child');

  static Widget app({required Widget child, bool disableAnimations = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(body: Center(child: child)),
      ),
    );
  }

  static T property<T>(WidgetTester tester, String name, {bool text = false}) {
    final renderObject = tester.renderObject<RenderObject>(
      find.descendant(
        of: find.byType(text ? TextMotion : Motion),
        matching: find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == (text ? '_OptimizedTextMotion' : '_MotionTransition'),
        ),
      ),
    );
    final property = renderObject.toDiagnosticsNode().getProperties().singleWhere(
      (property) => property.name == name,
    );
    return (property as DiagnosticsProperty<T>).value!;
  }

  static (double, double) state(WidgetTester tester) => (
    property<double>(tester, 'scale'),
    property<double>(tester, 'opacity'),
  );

  static Widget motion({PopMotionEffect effect = const PopMotionEffect(), MotionController? controller}) {
    return Motion(
      controller: controller,
      effect: effect,
      child: const SizedBox(key: childKey, width: 40, height: 20),
    );
  }
}

void main() {
  group('PopMotionEffect', () {
    test('when using defaults, it should use the agreed entrance configuration', () {
      const effect = PopMotionEffect();

      expect(
        (effect.scale, effect.delay, effect.duration, effect.curve, effect.playback),
        (0.75, Duration.zero, const Duration(milliseconds: 300), Curves.linear, MotionPlayback.once),
      );
    });

    testWidgets('when using defaults, it should scale and fade together from start to finish', (tester) async {
      await tester.pumpWidget(PopMotionEffectTestHelpers.app(child: PopMotionEffectTestHelpers.motion()));
      final start = PopMotionEffectTestHelpers.state(tester);
      await tester.pump(const Duration(milliseconds: 150));
      final middle = PopMotionEffectTestHelpers.state(tester);
      await tester.pump(const Duration(milliseconds: 150));

      expect([start, middle, PopMotionEffectTestHelpers.state(tester)], [(0.75, 0), (0.875, 0.5), (1, 1)]);
    });

    testWidgets('when configured, it should share the requested curve and timing between scale and fade', (
      tester,
    ) async {
      await tester.pumpWidget(
        PopMotionEffectTestHelpers.app(
          child: PopMotionEffectTestHelpers.motion(
            effect: const PopMotionEffect(
              scale: 0.4,
              duration: Duration(milliseconds: 400),
              curve: Curves.easeIn,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final progress = Curves.easeIn.transform(0.5);

      expect(
        PopMotionEffectTestHelpers.state(tester),
        (0.4 + 0.6 * progress, progress),
      );
    });

    testWidgets('when delayed, it should keep the initial state until playback starts', (tester) async {
      await tester.pumpWidget(
        PopMotionEffectTestHelpers.app(
          child: PopMotionEffectTestHelpers.motion(
            effect: const PopMotionEffect(delay: Duration(milliseconds: 100)),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(PopMotionEffectTestHelpers.state(tester), (0.75, 0));
    });

    testWidgets('when using an overshooting curve, it should grow past normal size', (tester) async {
      await tester.pumpWidget(
        PopMotionEffectTestHelpers.app(
          child: PopMotionEffectTestHelpers.motion(effect: const PopMotionEffect(curve: Curves.easeOutBack)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 210));

      expect(PopMotionEffectTestHelpers.property<double>(tester, 'scale'), greaterThan(1));
    });

    testWidgets('when scaling, it should preserve the layout size', (tester) async {
      await tester.pumpWidget(PopMotionEffectTestHelpers.app(child: PopMotionEffectTestHelpers.motion()));
      final initialSize = tester.getSize(find.byKey(PopMotionEffectTestHelpers.childKey));
      await tester.pump(const Duration(milliseconds: 150));

      expect(
        [initialSize, tester.getSize(find.byKey(PopMotionEffectTestHelpers.childKey))],
        [const Size(40, 20), const Size(40, 20)],
      );
    });

    testWidgets('when composed with other effects, it should multiply scale and opacity', (tester) async {
      await tester.pumpWidget(
        PopMotionEffectTestHelpers.app(
          child: const Motion.list(
            effects: [PopMotionEffect(), ScaleInMotionEffect(scale: 0.5), FadeInMotionEffect()],
            child: SizedBox(width: 40, height: 20),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));

      expect(PopMotionEffectTestHelpers.state(tester), (0.875 * 0.75, 0.25));
    });

    testWidgets('when applied to staggered text, it should scale and fade each character together', (tester) async {
      await tester.pumpWidget(
        PopMotionEffectTestHelpers.app(
          child: const TextMotion(
            effect: PopMotionEffect(),
            stagger: Duration(milliseconds: 150),
            child: Text('AB'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 150));

      expect(
        [
          PopMotionEffectTestHelpers.property<Iterable<double>>(tester, 'characterScales', text: true).toList(),
          PopMotionEffectTestHelpers.property<Iterable<double>>(tester, 'characterOpacities', text: true).toList(),
        ],
        [
          <double>[0.875, 0.75],
          <double>[0.5, 0],
        ],
      );
    });

    testWidgets('when reduced motion is enabled, it should show the completed entrance and call callbacks', (
      tester,
    ) async {
      final events = <String>[];
      await tester.pumpWidget(
        PopMotionEffectTestHelpers.app(
          disableAnimations: true,
          child: PopMotionEffectTestHelpers.motion(
            effect: PopMotionEffect(
              onStart: () => events.add('start'),
              onEnd: () => events.add('end'),
            ),
          ),
        ),
      );

      expect(
        (PopMotionEffectTestHelpers.state(tester), tester.hasRunningAnimations, events.join(',')),
        ((1, 1), false, 'start,end'),
      );
    });

    testWidgets('when replayed, it should restart both scale and fade', (tester) async {
      final controller = MotionController();
      await tester.pumpWidget(
        PopMotionEffectTestHelpers.app(child: PopMotionEffectTestHelpers.motion(controller: controller)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final completed = PopMotionEffectTestHelpers.state(tester);
      controller.play();
      await tester.pump();
      final restarted = PopMotionEffectTestHelpers.state(tester);
      await tester.pump(const Duration(milliseconds: 150));

      expect([completed, restarted, PopMotionEffectTestHelpers.state(tester)], [(1, 1), (0.75, 0), (0.875, 0.5)]);
    });

    for (final scale in [double.nan, double.infinity, double.negativeInfinity]) {
      test('when scale is $scale, it should reject construction', () {
        expect(() => PopMotionEffect(scale: scale), throwsAssertionError);
      });
    }
  });
}
