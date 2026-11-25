import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart' show ImageFilterLayer;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show MaterialApp;
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'composed_disintegrate_effect.dart';
import 'configured_disintegrate_effect.dart';
import 'disintegrate_test_harness.dart';

void main() {
  test('when using defaults, it should follow standard Motion timing', () {
    const effect = DisintegrateMotionEffect(direction: Offset.zero);
    expect(
      (effect.duration, effect.delay, effect.curve, effect.playback),
      (const Duration(milliseconds: 300), Duration.zero, Curves.linear, MotionPlayback.once),
    );
  });

  testWidgets('when held, it should keep the child without preparing a snapshot', (tester) async {
    final harness = DisintegrateTestHarness(tester);
    await harness.mount(effect: const DisintegrateMotionEffect(direction: Offset.zero));
    expect(harness.calls, isEmpty);
  });

  testWidgets('when held text is played between frames, it should use one paint for capture', (tester) async {
    final controller = MotionController();
    var starts = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Center(
          child: TextMotion(
            controller: controller,
            startup: .hold,
            effect: DisintegrateMotionEffect(direction: Offset.zero, onStart: () => starts++),
            child: const Text('Motion'),
          ),
        ),
      ),
    );

    controller
      ..play()
      ..play();
    await tester.pump(Duration.zero);
    await tester.pump();

    expect(starts, 1);
  });

  testWidgets('when an effect update is queued with play, it should capture the updated source', (tester) async {
    final harness = DisintegrateTestHarness(tester, native: true);
    final showSource = ValueNotifier(false);
    addTearDown(showSource.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Center(
          child: ValueListenableBuilder<bool>(
            valueListenable: showSource,
            builder: (context, visible, _) => Motion(
              controller: harness.motionController,
              startup: .hold,
              effect: ConfiguredDisintegrateEffect(progress: visible ? null : 1),
              child: const ColoredBox(color: Color(0xFF112233), child: SizedBox(width: 100, height: 60)),
            ),
          ),
        ),
      ),
    );

    harness.motionController.play();
    showSource.value = true;
    await harness.prepare();

    expect(harness.calls.where((call) => call.method == 'prepare'), hasLength(1));
  });

  testWidgets('when a first image is pending, it should wait before starting the effect', (tester) async {
    final harness = DisintegrateTestHarness(tester, native: true)..firstFrame = Completer<Object?>();
    var starts = 0;
    await harness.mount(
      effect: DisintegrateMotionEffect(direction: Offset.zero, onStart: () => starts++),
    );
    await harness.start();
    final before = starts;
    harness.firstFrame!.complete(null);
    await harness.prepare();
    expect((before, starts), (0, 1));
  });

  testWidgets('when native preparation fails, it should still start and complete using captured pixels', (
    tester,
  ) async {
    final harness = DisintegrateTestHarness(tester);
    final callbacks = <String>[];
    await harness.mount(
      effect: DisintegrateMotionEffect(
        direction: Offset.zero,
        onStart: () => callbacks.add('start'),
        onEnd: () => callbacks.add('end'),
      ),
    );
    await harness.start();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(callbacks, ['start', 'end']);
  });

  testWidgets('when direction magnitude changes, it should render the same particle path', (tester) async {
    final harness = DisintegrateTestHarness(tester);
    await harness.mount(effect: const ComposedDisintegrateEffect(direction: Offset(1, -1)));
    await harness.start();
    await tester.pump(const Duration(milliseconds: 700));
    final first = await harness.pixels();
    await tester.pumpWidget(const SizedBox.shrink());
    await harness.mount(effect: const ComposedDisintegrateEffect(direction: Offset(100, -100)));
    await harness.start();
    await tester.pump(const Duration(milliseconds: 700));
    final second = await harness.pixels();
    expect(second, first);
  });

  testWidgets('when scale changes operation order, it should change the rendered particle field', (tester) async {
    final harness = DisintegrateTestHarness(tester);
    await harness.mount(effect: const ComposedDisintegrateEffect());
    await harness.start();
    await tester.pump(const Duration(milliseconds: 700));
    final first = await harness.pixels();
    await tester.pumpWidget(const SizedBox.shrink());
    await harness.mount(effect: const ComposedDisintegrateEffect(scaleFirst: true));
    await harness.start();
    await tester.pump(const Duration(milliseconds: 700));
    final second = await harness.pixels();
    expect(second, isNot(first));
  });

  testWidgets('when two disintegrations are composed, it should preserve both stages', (tester) async {
    final harness = DisintegrateTestHarness(tester);
    await harness.mount(effect: const ComposedDisintegrateEffect());
    await harness.start();
    await tester.pump(const Duration(milliseconds: 700));
    final first = await harness.pixels();
    await tester.pumpWidget(const SizedBox.shrink());
    await harness.mount(effect: const ComposedDisintegrateEffect(secondStage: true));
    await harness.start();
    await tester.pump(const Duration(milliseconds: 700));
    final second = await harness.pixels();
    expect(second, isNot(first));
  });

  testWidgets('when reduced motion is requested, it should complete without preparing particles', (tester) async {
    final harness = DisintegrateTestHarness(tester);
    var completions = 0;
    await harness.mount(
      reducedMotion: true,
      effect: DisintegrateMotionEffect(direction: Offset.zero, onEnd: () => completions++),
    );
    await harness.start();
    expect((harness.calls.isEmpty, completions), (true, 1));
  });
  testWidgets('when playing on mount, it should capture after paint without build-phase errors', (tester) async {
    final harness = DisintegrateTestHarness(tester);
    var starts = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Center(
          child: Motion(
            effect: DisintegrateMotionEffect(direction: Offset.zero, onStart: () => starts++),
            child: const SizedBox(width: 100, height: 60),
          ),
        ),
      ),
    );
    await harness.prepare();
    expect((starts, tester.takeException()), (1, null));
  });

  testWidgets('when text is staggered, it should finish after the last visible grapheme', (tester) async {
    final harness = DisintegrateTestHarness(tester);
    var finishes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: TextMotion(
            controller: harness.motionController,
            startup: .hold,
            stagger: const Duration(milliseconds: 100),
            effect: DisintegrateMotionEffect(
              direction: Offset.zero,
              duration: const Duration(milliseconds: 300),
              onEnd: () => finishes++,
            ),
            child: const Text('A B👩‍💻'),
          ),
        ),
      ),
    );
    await harness.start();
    await tester.pump(const Duration(milliseconds: 350));
    final midway = finishes;
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect((midway, finishes, tester.takeException()), (0, 1, null));
  });

  testWidgets('when replaying, it should capture again and release the previous image', (tester) async {
    final harness = DisintegrateTestHarness(tester, native: true);
    await harness.mount(effect: const DisintegrateMotionEffect(direction: Offset.zero));
    await harness.start();
    await tester.pump(const Duration(milliseconds: 100));
    await harness.start();
    expect(harness.calls.where((call) => call.method == 'prepare').length, 2);
  });

  for (final initialProgress in [0.0, 0.25]) {
    testWidgets('when native particles start at $initialProgress and hold, it should animate blur without redrawing', (
      tester,
    ) async {
      final harness = DisintegrateTestHarness(tester, native: true);
      await harness.mount(effect: _HeldNativeBlur(initialProgress: initialProgress));
      await harness.start();
      await tester.pump(const Duration(milliseconds: 100));
      final firstFilter = tester.layers.whereType<ImageFilterLayer>().single.imageFilter;
      await tester.pump(const Duration(milliseconds: 100));
      final secondFilter = tester.layers.whereType<ImageFilterLayer>().single.imageFilter;
      final submittedProgress = harness.calls.where((call) => call.method == 'setFrame').map((call) {
        final arguments = call.arguments as Map<Object?, Object?>;
        return (arguments['frame']! as Float64List).first;
      });

      expect(
        [submittedProgress, firstFilter, secondFilter],
        [
          [if (initialProgress == 0) 0.0, 0.25],
          ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2, tileMode: .decal),
          ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4, tileMode: .decal),
        ],
      );
    });
  }

  testWidgets('when a native draw is pending, it should submit only the latest changed pose', (tester) async {
    final harness = DisintegrateTestHarness(tester, native: true);
    final firstMove = Completer<void>();
    final translations = <double>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(DisintegrateTestHarness.channel, (call) async {
      if (call.method == 'prepare') return {'textureId': 7, 'handle': 1};
      if (call.method == 'setFrame') {
        final arguments = call.arguments as Map<Object?, Object?>;
        final frame = arguments['frame']! as Float64List;
        translations.add(frame[7]);
        if (translations.length == 2) await firstMove.future;
      }
      return null;
    });
    await harness.mount(effect: const _HeldNativeBlur(translate: true));
    await harness.start();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    firstMove.complete();
    await tester.pump();

    expect(translations, [0, tester.view.devicePixelRatio, 3 * tester.view.devicePixelRatio]);
  });

  testWidgets('when two widgets play together, it should prepare independent native instances', (tester) async {
    final harness = DisintegrateTestHarness(tester, native: true);
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: Column(
          children: [
            for (var index = 0; index < 2; index++)
              Motion(
                controller: harness.motionController,
                startup: .hold,
                effect: const DisintegrateMotionEffect(direction: Offset.zero),
                child: const SizedBox(width: 100, height: 60),
              ),
          ],
        ),
      ),
    );
    await harness.start();
    final instances = harness.calls
        .where((call) => call.method == 'prepare')
        .map((call) => (call.arguments! as Map<Object?, Object?>)['instanceId'])
        .toSet();
    expect(instances.length, 2);
  });
  for (final progress in [-2.0, 0.0]) {
    testWidgets('when progress is $progress, it should preserve the original pixels', (tester) async {
      final harness = DisintegrateTestHarness(tester);
      await harness.mount(effect: ConfiguredDisintegrateEffect(progress: progress));
      final original = await harness.pixels();
      await harness.start();
      expect(await harness.pixels(), original);
    });
  }

  for (final progress in [1.0, 4.0]) {
    testWidgets('when progress is $progress, it should remove the original completely', (tester) async {
      final harness = DisintegrateTestHarness(tester);
      await harness.mount(effect: ConfiguredDisintegrateEffect(progress: progress));
      await harness.start();
      expect(
        find.descendant(of: find.byType(Motion), matching: find.byKey(const ValueKey('motion_render_surface'))),
        findsNothing,
      );
    });
  }

  testWidgets('when replaying deterministically, it should produce identical particles', (tester) async {
    final harness = DisintegrateTestHarness(tester);
    await harness.mount(effect: const ComposedDisintegrateEffect());
    await harness.start();
    await tester.pump(const Duration(milliseconds: 700));
    final first = await harness.pixels();
    await harness.start();
    await tester.pump(const Duration(milliseconds: 700));
    expect(await harness.pixels(), first);
  });

  testWidgets('when disposed during readiness, it should release its snapshot without starting', (tester) async {
    final harness = DisintegrateTestHarness(tester, native: true)..firstFrame = Completer<Object?>();
    var starts = 0;
    await harness.mount(
      effect: DisintegrateMotionEffect(direction: Offset.zero, onStart: () => starts++),
    );
    await harness.start();
    await tester.pumpWidget(const SizedBox.shrink());
    harness.firstFrame!.complete(null);
    await harness.prepare();
    expect((starts, harness.calls.any((call) => call.method == 'dispose'), tester.takeException()), (0, true, null));
  });

  testWidgets('when tickers suspend, it should pause autonomous native playback', (tester) async {
    final harness = DisintegrateTestHarness(tester, native: true);
    final enabled = ValueNotifier(true);
    addTearDown(enabled.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: .ltr,
        child: ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (context, value, child) => TickerMode(enabled: value, child: child!),
          child: Motion(
            controller: harness.motionController,
            startup: .hold,
            effect: const DisintegrateMotionEffect(direction: Offset.zero),
            child: const SizedBox(width: 120, height: 80),
          ),
        ),
      ),
    );
    await harness.start();
    enabled.value = false;
    await tester.pump();
    expect(harness.calls.any((call) => call.method == 'pause'), isTrue);
  });

  testWidgets('when looping, it should retain one capture across cycle boundaries', (tester) async {
    final harness = DisintegrateTestHarness(tester, native: true);
    await harness.mount(
      effect: const DisintegrateMotionEffect(direction: Offset.zero, playback: .loop),
    );
    await harness.start();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 350));
    expect((harness.calls.where((call) => call.method == 'prepare').length, tester.takeException()), (1, null));
  });

  testWidgets('when ordinary transforms play, it should allocate no particle resources', (tester) async {
    final harness = DisintegrateTestHarness(tester, native: true);
    await harness.mount(effect: const ScaleOutMotionEffect());
    await harness.start();
    expect(harness.calls, isEmpty);
  });

  testWidgets('when effects use Motion.list, it should preserve the same operation order as apply', (tester) async {
    final harness = DisintegrateTestHarness(tester);
    await harness.mount(effect: const ComposedDisintegrateEffect());
    await harness.start();
    await tester.pump(const Duration(milliseconds: 700));
    final combined = await harness.pixels();
    await tester.pumpWidget(const SizedBox.shrink());
    await harness.mount(
      effect: const ComposedDisintegrateEffect(),
      effects: const [
        ConfiguredDisintegrateEffect(direction: Offset(0, -1), duration: Duration(seconds: 2)),
        ScaleOutMotionEffect(scale: 0.5, duration: Duration(seconds: 2)),
      ],
    );
    await harness.start();
    await tester.pump(const Duration(milliseconds: 700));
    expect(await harness.pixels(), combined);
  });

  for (final direction in [const Offset(0, -1), const Offset(1, 0), const Offset(0, 1), const Offset(-1, 0)]) {
    testWidgets('when direction $direction is scaled, it should preserve its path', (tester) async {
      final harness = DisintegrateTestHarness(tester);
      await harness.mount(effect: ComposedDisintegrateEffect(direction: direction));
      await harness.start();
      await tester.pump(const Duration(milliseconds: 700));
      final normalized = await harness.pixels();
      await tester.pumpWidget(const SizedBox.shrink());
      await harness.mount(effect: ComposedDisintegrateEffect(direction: direction * 29));
      await harness.start();
      await tester.pump(const Duration(milliseconds: 700));
      expect(await harness.pixels(), normalized);
    });
  }

  testWidgets('when direction is zero, it should break up without moving any pixels outside the source', (
    tester,
  ) async {
    final harness = DisintegrateTestHarness(tester);
    await harness.mount(effect: const ConfiguredDisintegrateEffect(progress: 0.6));
    final original = await harness.pixels();
    await harness.start();
    final particles = await harness.pixels();
    var outsideChanged = false;
    for (var y = 0; y < 180; y++) {
      for (var x = 0; x < 240; x++) {
        if (x >= 60 && x < 180 && y >= 50 && y < 130) continue;
        final offset = (y * 240 + x) * 4;
        for (var channel = 0; channel < 4; channel++) {
          if (original[offset + channel] != particles[offset + channel]) outsideChanged = true;
        }
      }
    }
    expect((outsideChanged, listEquals(particles, original)), (false, false));
  });

  testWidgets('when render stages change during playback, it should diagnose the contract violation', (tester) async {
    final harness = DisintegrateTestHarness(tester);
    await harness.mount(effect: const ConfiguredDisintegrateEffect(changeTopology: true));
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('when an effect declares bounds, it should reserve those bounds for captured output', (tester) async {
    final harness = DisintegrateTestHarness(tester);
    await harness.mount(
      effect: const ConfiguredDisintegrateEffect(declaredBounds: MotionEffectBounds(maximumScale: 3)),
    );
    await harness.start();
    expect(tester.getSize(find.byKey(const ValueKey('motion_render_surface'))), const Size(360, 240));
  });

  testWidgets(
    'when text contains emoji and whitespace, it should use one batched surface and retain complete semantics',
    (tester) async {
      final harness = DisintegrateTestHarness(tester, native: true);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: TextMotion(
              controller: harness.motionController,
              startup: .hold,
              stagger: const Duration(milliseconds: 20),
              effect: const DisintegrateMotionEffect(direction: Offset.zero),
              child: const Text('A B👩‍💻'),
            ),
          ),
        ),
      );
      await harness.start();
      expect(
        (
          find.byKey(const ValueKey('motion_render_surface')).evaluate().length,
          harness.calls.where((call) => call.method == 'prepare').length,
          find.bySemanticsLabel('A B👩‍💻').evaluate().length,
        ),
        (1, 0, 1),
      );
      semantics.dispose();
    },
  );

  testWidgets('when the source is empty, it should skip preparation and complete callbacks', (tester) async {
    final harness = DisintegrateTestHarness(tester);
    final callbacks = <String>[];
    await harness.mount(
      effect: DisintegrateMotionEffect(
        direction: Offset.zero,
        onStart: () => callbacks.add('start'),
        onEnd: () => callbacks.add('end'),
      ),
      child: const SizedBox.shrink(),
    );
    await harness.start();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect((callbacks.join(','), harness.calls.isEmpty), ('start,end', true));
  });
}

class _HeldNativeBlur extends MotionEffect {
  const new({this.initialProgress = 0, this.translate = false}) : super(duration: const Duration(milliseconds: 400));

  final double initialProgress;
  final bool translate;

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform
      ..disintegrate(progress: progress == 0 ? initialProgress : 0.25, direction: Offset.zero)
      ..translate(x: translate ? 4 * progress : 0, y: 0)
      ..blur(8 * progress);
  }
}
