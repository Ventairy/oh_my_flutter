import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  testWidgets('when mounted before the deadline, it should build immediately with the remaining duration', (
    tester,
  ) async {
    await CountdownBuilderTestScene.run(tester, (scene) async {
      await scene.mount(endsAt: clock.now().add(const Duration(seconds: 12)));
      expect(scene.remaining, const Duration(seconds: 12));
    });
  });

  testWidgets('when mounted at different times, it should update on the same deadline boundaries', (tester) async {
    await CountdownBuilderTestScene.run(tester, (scene) async {
      final endsAt = clock.now().add(const Duration(seconds: 13));
      await scene.mount(endsAt: endsAt);
      await tester.pump(const Duration(seconds: 1));
      await scene.mount(endsAt: endsAt, showSecond: true);
      await tester.pump(const Duration(seconds: 2, microseconds: 1));
      expect(
        (scene.remaining, scene.secondRemaining),
        (const Duration(seconds: 9, microseconds: 999999), const Duration(seconds: 9, microseconds: 999999)),
      );
    });
  });

  testWidgets('when expiry comes before an interval elapses, it should deliver zero before completing once', (
    tester,
  ) async {
    await CountdownBuilderTestScene.run(tester, (scene) async {
      await scene.mount(endsAt: clock.now().add(const Duration(seconds: 2)));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 10));
      expect(scene.completions, [Duration.zero]);
    });
  });

  testWidgets('when supplied an expired deadline, it should render zero without calling completion', (tester) async {
    await CountdownBuilderTestScene.run(tester, (scene) async {
      await scene.mount(endsAt: clock.now().subtract(const Duration(seconds: 1)));
      await tester.pump(const Duration(seconds: 1));
      expect((scene.remaining, scene.completions.length), (Duration.zero, 0));
    });
  });

  testWidgets('when resuming after background expiry, it should catch up and complete once', (tester) async {
    await CountdownBuilderTestScene.run(tester, (scene) async {
      await scene.mount(endsAt: clock.now().add(const Duration(seconds: 2)));
      tester.binding.handleAppLifecycleStateChanged(.paused);
      await tester.pump(const Duration(seconds: 3));
      final whilePaused = (scene.remaining, scene.completions.length);
      tester.binding.handleAppLifecycleStateChanged(.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect((whilePaused, scene.completions.single), ((const Duration(seconds: 2), 0), Duration.zero));
    });
  });

  testWidgets('when the deadline is replaced, it should complete only the new active deadline', (tester) async {
    await CountdownBuilderTestScene.run(tester, (scene) async {
      await scene.mount(endsAt: clock.now().add(const Duration(seconds: 2)));
      await tester.pump(const Duration(seconds: 1));
      await scene.mount(endsAt: clock.now().add(const Duration(seconds: 3)));
      await tester.pump(const Duration(seconds: 1));
      final originalCompletionCount = scene.completions.length;
      await tester.pump(const Duration(seconds: 2));
      expect((originalCompletionCount, scene.completions.single), (0, Duration.zero));
    });
  });

  testWidgets('when the interval changes, it should use the new deadline-aligned cadence', (tester) async {
    await CountdownBuilderTestScene.run(tester, (scene) async {
      final endsAt = clock.now().add(const Duration(seconds: 13));
      await scene.mount(endsAt: endsAt);
      await tester.pump(const Duration(seconds: 1));
      await scene.mount(endsAt: endsAt, interval: const Duration(seconds: 2));
      await tester.pump(const Duration(microseconds: 1));
      expect(scene.remaining, const Duration(seconds: 11, microseconds: 999999));
    });
  });

  testWidgets('when disposed before expiry, it should cancel updates and completion', (tester) async {
    await CountdownBuilderTestScene.run(tester, (scene) async {
      await scene.mount(endsAt: clock.now().add(const Duration(seconds: 2)));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      expect(scene.completions, isEmpty);
    });
  });
}

class CountdownBuilderTestScene {
  new(this.tester);

  final WidgetTester tester;
  final completions = <Duration>[];
  Duration remaining = Duration.zero;
  Duration secondRemaining = Duration.zero;

  static Future<void> run(
    WidgetTester tester,
    Future<void> Function(CountdownBuilderTestScene scene) test,
  ) => withClock(Clock(() => tester.binding.clock.now()), () => test(CountdownBuilderTestScene(tester)));

  Future<void> mount({
    required DateTime endsAt,
    Duration interval = const Duration(seconds: 5),
    bool showSecond = false,
  }) => tester.pumpWidget(
    Directionality(
      textDirection: .ltr,
      child: Column(
        children: [
          CountdownBuilder(
            endsAt: endsAt,
            updateInterval: interval,
            onComplete: () => completions.add(remaining),
            builder: (context, value) {
              remaining = value;
              return const SizedBox.shrink();
            },
          ),
          if (showSecond)
            CountdownBuilder(
              endsAt: endsAt,
              updateInterval: interval,
              builder: (context, value) {
                secondRemaining = value;
                return const SizedBox.shrink();
              },
            ),
        ],
      ),
    ),
  );
}
