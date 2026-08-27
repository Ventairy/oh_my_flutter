import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

RenderObject _findSkeletonRenderObject(WidgetTester tester) {
  return tester.renderObject(
    find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_SkeletonRenderObjectWidget',
    ),
  );
}

MaterialApp _app({required Widget child, Key? key}) {
  return MaterialApp(
    key: key,
    theme: ThemeData(),
    home: Scaffold(body: child),
  );
}

MaterialApp _pixelApp({required Key boundaryKey, required Widget child}) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: RepaintBoundary(
          key: boundaryKey,
          child: child,
        ),
      ),
    ),
  );
}

Future<({int height, List<int> pixels, int width})> _capturePixels(
  WidgetTester tester,
  Key boundaryKey,
) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return (
        height: image.height,
        pixels: List<int>.generate(
          bytes!.lengthInBytes,
          bytes.getUint8,
          growable: false,
        ),
        width: image.width,
      );
    } finally {
      image.dispose();
    }
  }))!;
}

Color _pixelAt(
  ({int height, List<int> pixels, int width}) frame,
  int x,
  int y,
) {
  final offset = (y * frame.width + x) * 4;
  return Color.fromARGB(
    frame.pixels[offset + 3],
    frame.pixels[offset],
    frame.pixels[offset + 1],
    frame.pixels[offset + 2],
  );
}

bool _containsSaturatedSourcePixel(
  ({int height, List<int> pixels, int width}) frame,
) {
  for (var offset = 0; offset < frame.pixels.length; offset += 4) {
    final red = frame.pixels[offset];
    final green = frame.pixels[offset + 1];
    final blue = frame.pixels[offset + 2];
    final alpha = frame.pixels[offset + 3];
    if (alpha == 0) continue;

    final redSource = red > 160 && red > green + 80 && red > blue + 80;
    final greenSource = green > 140 && green > red + 70 && green > blue + 70;
    final blueSource = blue > 160 && blue > red + 80 && blue > green + 60;
    if (redSource || greenSource || blueSource) return true;
  }
  return false;
}

void main() {
  group('Skeleton', () {
    testWidgets('when enabled is false, it should render the child unchanged', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(child: const Skeleton(enabled: false, child: Text('Hello'))),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets(
      'when a semantics label is provided, it should expose one live loading status and hide child semantics',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _app(
            child: Skeleton(
              semanticsLabel: 'Loading profile',
              child: Semantics(
                label: 'Loaded profile',
                child: const Text('Profile'),
              ),
            ),
          ),
        );

        final loading = find.bySemanticsLabel('Loading profile');
        final loadingCount = loading.evaluate().length;
        final loadedCount = find.bySemanticsLabel('Loaded profile').evaluate().length;
        final data = tester.getSemantics(loading).getSemanticsData();
        semantics.dispose();

        expect(
          (
            loadingCount: loadingCount,
            loadedCount: loadedCount,
            liveRegion: data.flagsCollection.isLiveRegion,
            role: data.role,
          ),
          (
            loadingCount: 1,
            loadedCount: 0,
            liveRegion: true,
            role: SemanticsRole.loadingSpinner,
          ),
        );
      },
    );

    testWidgets(
      'when no animated effect is provided, it should not schedule a frame callback',
      (tester) async {
        await tester.pumpWidget(
          _app(child: const Skeleton(child: Text('Hello'))),
        );

        expect(tester.binding.transientCallbackCount, 0);
      },
    );

    testWidgets(
      'when style.effect is a SkeletonShimmerEffect, it should schedule one frame callback',
      (tester) async {
        await tester.pumpWidget(
          _app(
            child: const Skeleton(
              style: SkeletonStyle(effect: SkeletonShimmerEffect()),
              child: Text('Hello'),
            ),
          ),
        );

        expect(tester.binding.transientCallbackCount, 1);
      },
    );

    testWidgets(
      'when style.effect is a SkeletonFadeEffect, it should schedule one frame callback',
      (tester) async {
        await tester.pumpWidget(
          _app(
            child: const Skeleton(
              style: SkeletonStyle(effect: SkeletonFadeEffect()),
              child: Text('Hello'),
            ),
          ),
        );

        expect(tester.binding.transientCallbackCount, 1);
      },
    );

    testWidgets(
      'when an animated skeleton captures no bones, it should stop its frame callback',
      (tester) async {
        await tester.pumpWidget(
          _app(
            child: const Skeleton(
              style: SkeletonStyle(effect: SkeletonShimmerEffect()),
              child: SizedBox(width: 100, height: 40),
            ),
          ),
        );

        expect(tester.binding.transientCallbackCount, 0);
      },
    );

    testWidgets(
      'when an animated effect has a non-positive duration, it should remain static without a frame callback',
      (tester) async {
        await tester.pumpWidget(
          _app(
            child: const Column(
              children: [
                Skeleton(
                  style: SkeletonStyle(
                    effect: SkeletonFadeEffect(duration: Duration.zero),
                  ),
                  child: Text('Zero'),
                ),
                Skeleton(
                  style: SkeletonStyle(
                    effect: SkeletonShimmerEffect(
                      duration: Duration(milliseconds: -1),
                    ),
                  ),
                  child: Text('Negative'),
                ),
              ],
            ),
          ),
        );

        expect(tester.binding.transientCallbackCount, 0);
      },
    );

    testWidgets(
      'when the platform disables animations with style.effect, it should not schedule shimmer frames',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(),
            home: const MediaQuery(
              data: MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: Skeleton(
                  style: SkeletonStyle(
                    effect: SkeletonShimmerEffect(),
                  ),
                  child: Text('Hello'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );

    testWidgets(
      'when skeletonizing a child, it should isolate repaint work inside a render boundary',
      (tester) async {
        await tester.pumpWidget(
          _app(child: const Skeleton(child: Text('Hello'))),
        );

        final renderObject = _findSkeletonRenderObject(tester);

        expect(renderObject.isRepaintBoundary, isTrue);
      },
    );

    testWidgets(
      'when skeletonizing a child, the render object should require compositing',
      (tester) async {
        await tester.pumpWidget(
          _app(child: const Skeleton(child: Text('Hello'))),
        );

        final renderObject = _findSkeletonRenderObject(tester);

        expect(renderObject.needsCompositing, isTrue);
      },
    );

    testWidgets(
      'when the widget rebuilds with style.effect toggled, it should update the render object',
      (tester) async {
        await tester.pumpWidget(
          _app(
            child: const Skeleton(
              style: SkeletonStyle(effect: SkeletonShimmerEffect()),
              child: Text('Hello'),
            ),
          ),
        );
        await tester.pumpWidget(
          _app(child: const Skeleton(child: Text('Hello'))),
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'when the widget rebuilds with style.effect toggled off then on, the render object persists',
      (tester) async {
        await tester.pumpWidget(
          _app(
            child: const Skeleton(
              style: SkeletonStyle(effect: SkeletonShimmerEffect()),
              child: Text('Hello'),
            ),
          ),
        );
        final renderObject = _findSkeletonRenderObject(tester);

        await tester.pumpWidget(
          _app(child: const Skeleton(child: Text('Hello'))),
        );
        await tester.pumpWidget(
          _app(
            child: const Skeleton(
              style: SkeletonStyle(effect: SkeletonShimmerEffect()),
              child: Text('Hello'),
            ),
          ),
        );
        expect(_findSkeletonRenderObject(tester), same(renderObject));
      },
    );

    testWidgets(
      'when style.effect toggles via widget rebuild, setter markNeedsPaint should not throw',
      (tester) async {
        await tester.pumpWidget(
          _app(child: const Skeleton(child: Text('Hello'))),
        );

        await tester.pumpWidget(
          _app(
            child: const Skeleton(
              style: SkeletonStyle(effect: SkeletonShimmerEffect()),
              child: Text('Hello'),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'when only the effect advances, it should retain the child paint output',
      (tester) async {
        final painter = _PaintCounter();
        await tester.pumpWidget(
          _app(
            child: Skeleton(
              style: const SkeletonStyle(
                effect: SkeletonShimmerEffect(),
              ),
              child: CustomPaint(
                size: const Size(100, 40),
                painter: painter,
              ),
            ),
          ),
        );
        final paintsAfterCapture = painter.paintCount;

        for (var frame = 0; frame < 20; frame += 1) {
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(paintsAfterCapture, greaterThan(0));
        expect(painter.paintCount, paintsAfterCapture);
      },
    );

    testWidgets(
      'when the child requests paint, it should rebuild the retained scene once',
      (tester) async {
        final repaint = ValueNotifier<int>(0);
        final painter = _PaintCounter(repaint: repaint);
        addTearDown(repaint.dispose);
        await tester.pumpWidget(
          _app(
            child: Skeleton(
              style: const SkeletonStyle(
                effect: SkeletonShimmerEffect(),
              ),
              child: CustomPaint(
                size: const Size(100, 40),
                painter: painter,
              ),
            ),
          ),
        );
        final paintsAfterCapture = painter.paintCount;

        repaint.value += 1;
        await tester.pump();
        final paintsAfterInvalidation = painter.paintCount;
        await tester.pump(const Duration(milliseconds: 16));

        expect(paintsAfterInvalidation, paintsAfterCapture + 1);
        expect(painter.paintCount, paintsAfterInvalidation);
      },
    );

    testWidgets(
      'when many skeletons animate, they should share one frame callback',
      (tester) async {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              children: List<Widget>.generate(
                16,
                (_) => const Skeleton(
                  style: SkeletonStyle(
                    effect: SkeletonShimmerEffect(),
                  ),
                  child: SizedBox(
                    width: 100,
                    height: 8,
                    child: ColoredBox(color: Colors.red),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.binding.transientCallbackCount, 1);
      },
    );

    testWidgets(
      'when enabled changes, it should preserve the child state object',
      (tester) async {
        final childKey = GlobalKey<_TickingChildState>();
        late StateSetter setState;
        var enabled = true;
        await tester.pumpWidget(
          _app(
            child: StatefulBuilder(
              builder: (context, update) {
                setState = update;
                return Skeleton(
                  enabled: enabled,
                  child: _TickingChild(key: childKey),
                );
              },
            ),
          ),
        );
        final initialState = childKey.currentState;

        setState(() => enabled = false);
        await tester.pump();
        setState(() => enabled = true);
        await tester.pump();

        expect(childKey.currentState, same(initialState));
      },
    );

    testWidgets(
      'when enabled, it should mute animation tickers in the hidden child',
      (tester) async {
        final childKey = GlobalKey<_TickingChildState>();
        late StateSetter setState;
        var enabled = true;
        await tester.pumpWidget(
          _app(
            child: StatefulBuilder(
              builder: (context, update) {
                setState = update;
                return Skeleton(
                  enabled: enabled,
                  child: _TickingChild(key: childKey),
                );
              },
            ),
          ),
        );
        final ticksWhileLoading = childKey.currentState!.ticks;

        await tester.pump(const Duration(milliseconds: 160));
        expect(childKey.currentState!.ticks, ticksWhileLoading);

        setState(() => enabled = false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 160));

        expect(childKey.currentState!.ticks, greaterThan(ticksWhileLoading));
      },
    );

    testWidgets(
      'when enabled, it should prevent interaction with the hidden child',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _app(
            child: Skeleton(
              child: TextButton(
                onPressed: () => taps += 1,
                child: const Text('Action'),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(TextButton), warnIfMissed: false);

        expect(taps, 0);
      },
    );

    testWidgets(
      'when enabled after a button receives focus, it should prevent keyboard activation',
      (tester) async {
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        late StateSetter updateSkeleton;
        var enabled = false;
        var activations = 0;
        await tester.pumpWidget(
          _app(
            child: StatefulBuilder(
              builder: (context, setState) {
                updateSkeleton = setState;
                return Skeleton(
                  enabled: enabled,
                  child: TextButton(
                    focusNode: focusNode,
                    onPressed: () => activations += 1,
                    child: const Text('Action'),
                  ),
                );
              },
            ),
          ),
        );

        focusNode.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        updateSkeleton(() => enabled = true);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(activations, 1);
      },
    );

    testWidgets(
      'when enabled while a descendant is focused, it should clear that focus',
      (tester) async {
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        late StateSetter updateSkeleton;
        var enabled = false;
        await tester.pumpWidget(
          _app(
            child: StatefulBuilder(
              builder: (context, setState) {
                updateSkeleton = setState;
                return Skeleton(
                  enabled: enabled,
                  child: TextButton(
                    focusNode: focusNode,
                    onPressed: () {},
                    child: const Text('Action'),
                  ),
                );
              },
            ),
          ),
        );

        focusNode.requestFocus();
        await tester.pump();
        updateSkeleton(() => enabled = true);
        await tester.pump();

        expect(focusNode.hasFocus, isFalse);
      },
    );

    testWidgets(
      'when enabled while a text field is focused, it should close the text input connection',
      (tester) async {
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        late StateSetter updateSkeleton;
        var enabled = false;
        await tester.pumpWidget(
          _app(
            child: StatefulBuilder(
              builder: (context, setState) {
                updateSkeleton = setState;
                return Skeleton(
                  enabled: enabled,
                  child: TextField(focusNode: focusNode),
                );
              },
            ),
          ),
        );

        await tester.tap(find.byType(TextField));
        await tester.pump();
        updateSkeleton(() => enabled = true);
        await tester.pump();

        expect(tester.testTextInput.hasAnyClients, isFalse);
      },
    );

    testWidgets(
      'when disabled after loading, it should allow descendant focus again',
      (tester) async {
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);
        late StateSetter updateSkeleton;
        var enabled = true;
        await tester.pumpWidget(
          _app(
            child: StatefulBuilder(
              builder: (context, setState) {
                updateSkeleton = setState;
                return Skeleton(
                  enabled: enabled,
                  child: TextButton(
                    focusNode: focusNode,
                    onPressed: () {},
                    child: const Text('Action'),
                  ),
                );
              },
            ),
          ),
        );

        updateSkeleton(() => enabled = false);
        await tester.pump();
        focusNode.requestFocus();
        await tester.pump();

        expect(focusNode.hasFocus, isTrue);
      },
    );
  });

  group('Skeleton visual output', () {
    testWidgets(
      'when a custom style color is provided, it should paint the bone with that exact color',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-style-color-boundary');
        const boneColor = Color(0xFF536579);
        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: const Skeleton(
              style: SkeletonStyle(color: boneColor, radius: Radius.zero),
              child: SizedBox(
                width: 40,
                height: 24,
                child: ColoredBox(color: Colors.red),
              ),
            ),
          ),
        );

        final frame = await _capturePixels(tester, boundaryKey);

        expect(_pixelAt(frame, 20, 12).toARGB32(), boneColor.toARGB32());
      },
    );

    testWidgets(
      'when a rounded radius is provided, it should leave the corner clear and fill the center',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-radius-boundary');
        const boneColor = Color(0xFF536579);
        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: const Skeleton(
              style: SkeletonStyle(
                color: boneColor,
                radius: Radius.circular(12),
              ),
              child: SizedBox(
                width: 40,
                height: 40,
                child: ColoredBox(color: Colors.red),
              ),
            ),
          ),
        );

        final frame = await _capturePixels(tester, boundaryKey);

        expect(
          (
            cornerAlpha: _pixelAt(frame, 1, 1).a,
            center: _pixelAt(frame, 20, 20).toARGB32(),
          ),
          (cornerAlpha: 0.0, center: boneColor.toARGB32()),
        );
      },
    );

    testWidgets(
      'when a paragraph has multiple lines, it should match each tight text line box',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-paragraph-spacing-boundary');
        const boneColor = Color(0xFF536579);
        const textStyle = TextStyle(fontSize: 20, height: 1.5);

        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: const SizedBox(
              width: 45,
              height: 90,
              child: Skeleton(
                style: SkeletonStyle(color: boneColor, radius: Radius.zero),
                child: Text('AA\nAAA', style: textStyle),
              ),
            ),
          ),
        );

        final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
        final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
        final paragraphOffset = paragraph.localToGlobal(Offset.zero, ancestor: boundary);
        final expectedBoxes = const [(0, 2), (3, 5), (5, 6)]
            .map(
              (range) => paragraph
                  .getBoxesForSelection(
                    TextSelection(baseOffset: range.$1, extentOffset: range.$2),
                    boxHeightStyle: ui.BoxHeightStyle.tight,
                    boxWidthStyle: ui.BoxWidthStyle.tight,
                  )
                  .single
                  .toRect()
                  .shift(paragraphOffset),
            )
            .toList();
        final frame = await _capturePixels(tester, boundaryKey);
        final lineBoundaries = <int>[0];
        for (var index = 1; index < expectedBoxes.length; index += 1) {
          lineBoundaries.add(
            ((expectedBoxes[index - 1].bottom + expectedBoxes[index].top) / 2).floor(),
          );
        }
        lineBoundaries.add(frame.height);
        final actualBounds = <Rect>[];
        for (var index = 0; index < expectedBoxes.length; index += 1) {
          final startY = lineBoundaries[index];
          final endY = lineBoundaries[index + 1];
          var left = frame.width;
          var top = frame.height;
          var right = -1;
          var bottom = -1;
          for (var y = startY; y < endY; y += 1) {
            for (var x = 0; x < frame.width; x += 1) {
              if (_pixelAt(frame, x, y).a == 0) continue;
              left = math.min(left, x);
              top = math.min(top, y);
              right = math.max(right, x);
              bottom = math.max(bottom, y);
            }
          }
          actualBounds.add(Rect.fromLTRB(left.toDouble(), top.toDouble(), right + 1, bottom + 1));
        }

        expect(
          actualBounds,
          expectedBoxes
              .map(
                (box) => Rect.fromLTRB(
                  box.left.floorToDouble(),
                  box.top.floorToDouble(),
                  box.right.ceilToDouble(),
                  box.bottom.ceilToDouble(),
                ),
              )
              .toList(),
        );
      },
    );

    testWidgets(
      'when a fade effect advances, it should update retained layer pixels',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-animated-fade-boundary');
        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: const Skeleton(
              style: SkeletonStyle(
                color: Colors.black,
                radius: Radius.zero,
                effect: SkeletonFadeEffect(),
              ),
              child: SizedBox(
                width: 40,
                height: 24,
                child: ColoredBox(color: Colors.red),
              ),
            ),
          ),
        );
        final alphaValues = <double>{};

        for (var sample = 0; sample < 8; sample += 1) {
          await tester.pump(const Duration(milliseconds: 125));
          final frame = await _capturePixels(tester, boundaryKey);
          alphaValues.add(_pixelAt(frame, 20, 12).a);
        }

        expect(alphaValues.length, greaterThan(2));
      },
    );

    testWidgets(
      'when shimmer bones cross composited segments, it should keep one continuous phase',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-shimmer-segment-boundary');
        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: const Skeleton(
              style: SkeletonStyle(
                color: Colors.black,
                radius: Radius.zero,
                effect: SkeletonShimmerEffect(color: Colors.white),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 50,
                    height: 20,
                    child: ColoredBox(color: Colors.red),
                  ),
                  ClipRect(
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: 50,
                      height: 20,
                      child: ColoredBox(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        var largestBoundaryDelta = 0;

        for (var sample = 0; sample < 15; sample += 1) {
          await tester.pump(const Duration(milliseconds: 100));
          final frame = await _capturePixels(tester, boundaryKey);
          final left = _pixelAt(frame, 49, 10);
          final right = _pixelAt(frame, 50, 10);
          final delta = (left.r * 255 - right.r * 255).abs().round();
          largestBoundaryDelta = math.max(largestBoundaryDelta, delta);
        }

        expect(largestBoundaryDelta, lessThanOrEqualTo(24));
      },
    );

    testWidgets(
      'when active and paused fades share a frame, it should keep the paused effect at its start',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-paused-effect-boundary');
        var pausedRadius = Radius.zero;
        late StateSetter update;
        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Skeleton(
                      style: SkeletonStyle(
                        color: Colors.black,
                        radius: Radius.zero,
                        effect: SkeletonFadeEffect(),
                      ),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: ColoredBox(color: Colors.red),
                      ),
                    ),
                    TickerMode(
                      enabled: false,
                      child: Skeleton(
                        style: SkeletonStyle(
                          color: Colors.black,
                          radius: pausedRadius,
                          effect: const SkeletonFadeEffect(),
                        ),
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: ColoredBox(color: Colors.blue),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 250));
        update(() => pausedRadius = const Radius.circular(1));
        await tester.pump();
        final frame = await _capturePixels(tester, boundaryKey);
        final pausedAlpha = _pixelAt(frame, 30, 10).toARGB32() >>> 24;

        expect(pausedAlpha, 102);
      },
    );

    testWidgets(
      'when nested repaint boundaries wrap a source color, it should flatten them into one clean bone',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-repaint-boundary');
        const boneColor = Color(0xFF536579);
        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: const Skeleton(
              style: SkeletonStyle(color: boneColor, radius: Radius.zero),
              child: RepaintBoundary(
                child: RepaintBoundary(
                  child: SizedBox(
                    width: 40,
                    height: 24,
                    child: ColoredBox(color: Colors.red),
                  ),
                ),
              ),
            ),
          ),
        );

        final frame = await _capturePixels(tester, boundaryKey);

        expect(
          (
            center: _pixelAt(frame, 20, 12).toARGB32(),
            sourceColorVisible: _containsSaturatedSourcePixel(frame),
          ),
          (center: boneColor.toARGB32(), sourceColorVisible: false),
        );
      },
    );

    testWidgets(
      'when a boundary child repaints while enabled, it should keep stable bones and reveal the update later',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-repainting-boundary');
        const boneColor = Color(0xFF536579);
        final repaint = ValueNotifier<({Color color, double inset})>(
          (color: Colors.red, inset: 0),
        );
        final painter = _MutableGeometryPainter(repaint);
        var enabled = true;
        late StateSetter updateSkeleton;
        addTearDown(repaint.dispose);

        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: StatefulBuilder(
              builder: (context, setState) {
                updateSkeleton = setState;
                return Skeleton(
                  enabled: enabled,
                  style: const SkeletonStyle(
                    color: boneColor,
                    radius: Radius.zero,
                  ),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: const Size(40, 24),
                      painter: painter,
                    ),
                  ),
                );
              },
            ),
          ),
        );
        final paintsBeforeChange = painter.paintCount;

        repaint.value = (color: Colors.blue, inset: 8);
        await tester.pump();
        final enabledFrame = await _capturePixels(tester, boundaryKey);
        final paintsWhileEnabled = painter.paintCount;

        updateSkeleton(() => enabled = false);
        await tester.pump();
        final disabledFrame = await _capturePixels(tester, boundaryKey);

        expect(
          (
            enabledCenter: _pixelAt(enabledFrame, 20, 12).toARGB32(),
            enabledEdge: _pixelAt(enabledFrame, 1, 1).toARGB32(),
            enabledSourceVisible: _containsSaturatedSourcePixel(enabledFrame),
            repaintsWhileEnabled: paintsWhileEnabled - paintsBeforeChange,
            disabledCenter: _pixelAt(disabledFrame, 20, 12).toARGB32(),
            disabledEdgeAlpha: _pixelAt(disabledFrame, 1, 1).a,
            repaintsAfterDisable: painter.paintCount - paintsWhileEnabled,
          ),
          (
            enabledCenter: boneColor.toARGB32(),
            enabledEdge: boneColor.toARGB32(),
            enabledSourceVisible: false,
            repaintsWhileEnabled: 0,
            disabledCenter: Colors.blue.toARGB32(),
            disabledEdgeAlpha: 0.0,
            repaintsAfterDisable: 1,
          ),
        );
      },
    );

    testWidgets(
      'when opacity wraps a source color, it should not fade or tint the skeleton bone',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-opacity-boundary');
        const boneColor = Color(0xFF536579);
        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: const Skeleton(
              style: SkeletonStyle(color: boneColor, radius: Radius.zero),
              child: Opacity(
                opacity: 0.15,
                child: SizedBox(
                  width: 40,
                  height: 24,
                  child: ColoredBox(color: Colors.green),
                ),
              ),
            ),
          ),
        );

        final frame = await _capturePixels(tester, boundaryKey);

        expect(
          (
            center: _pixelAt(frame, 20, 12).toARGB32(),
            sourceColorVisible: _containsSaturatedSourcePixel(frame),
          ),
          (center: boneColor.toARGB32(), sourceColorVisible: false),
        );
      },
    );

    testWidgets(
      'when an opacity boundary changes while enabled, it should keep stable bones and reveal the latest child later',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-repainting-opacity-boundary');
        const boneColor = Color(0xFF536579);
        final repaint = ValueNotifier<({Color color, double inset})>(
          (color: Colors.green, inset: 0),
        );
        final painter = _MutableGeometryPainter(repaint);
        var enabled = true;
        late StateSetter updateSkeleton;
        addTearDown(repaint.dispose);

        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: StatefulBuilder(
              builder: (context, setState) {
                updateSkeleton = setState;
                return Skeleton(
                  enabled: enabled,
                  style: const SkeletonStyle(
                    color: boneColor,
                    radius: Radius.zero,
                  ),
                  child: Opacity(
                    opacity: 0.15,
                    child: CustomPaint(
                      size: const Size(40, 24),
                      painter: painter,
                    ),
                  ),
                );
              },
            ),
          ),
        );
        final initialPaintCount = painter.paintCount;

        repaint.value = (color: Colors.red, inset: 4);
        await tester.pump();
        repaint.value = (color: Colors.blue, inset: 8);
        await tester.pump();
        final enabledFrame = await _capturePixels(tester, boundaryKey);
        final paintsWhileEnabled = painter.paintCount;

        updateSkeleton(() => enabled = false);
        await tester.pump();
        final disabledFrame = await _capturePixels(tester, boundaryKey);
        final disabledCenter = _pixelAt(disabledFrame, 20, 12);

        expect(
          (
            initiallyPainted: initialPaintCount,
            repaintsWhileEnabled: paintsWhileEnabled - initialPaintCount,
            enabledCenter: _pixelAt(enabledFrame, 20, 12).toARGB32(),
            enabledEdge: _pixelAt(enabledFrame, 1, 1).toARGB32(),
            enabledSourceVisible: _containsSaturatedSourcePixel(enabledFrame),
            repaintsAfterDisable: painter.paintCount - paintsWhileEnabled,
            disabledCenterVisible: disabledCenter.a > 0,
            disabledCenterIsBlue: disabledCenter.b > disabledCenter.g && disabledCenter.g > disabledCenter.r,
            disabledEdgeAlpha: _pixelAt(disabledFrame, 5, 5).a,
          ),
          (
            initiallyPainted: 0,
            repaintsWhileEnabled: 0,
            enabledCenter: boneColor.toARGB32(),
            enabledEdge: boneColor.toARGB32(),
            enabledSourceVisible: false,
            repaintsAfterDisable: 1,
            disabledCenterVisible: true,
            disabledCenterIsBlue: true,
            disabledEdgeAlpha: 0.0,
          ),
        );
      },
    );

    testWidgets(
      'when a color filter wraps a source color, it should leave exact skeleton pixels unfiltered',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-color-filter-boundary');
        const boneColor = Color(0xFF536579);
        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: const Skeleton(
              style: SkeletonStyle(color: boneColor, radius: Radius.zero),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(Colors.red, BlendMode.srcIn),
                child: SizedBox(
                  width: 40,
                  height: 24,
                  child: ColoredBox(color: Colors.green),
                ),
              ),
            ),
          ),
        );

        final frame = await _capturePixels(tester, boundaryKey);

        expect(
          (
            center: _pixelAt(frame, 20, 12).toARGB32(),
            sourceColorVisible: _containsSaturatedSourcePixel(frame),
          ),
          (center: boneColor.toARGB32(), sourceColorVisible: false),
        );
      },
    );

    testWidgets(
      'when repaint boundary, opacity, and shader mask layers nest, they should leave the bone clean',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-shader-mask-boundary');
        const boneColor = Color(0xFF536579);
        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: Skeleton(
              style: const SkeletonStyle(
                color: boneColor,
                radius: Radius.zero,
              ),
              child: RepaintBoundary(
                child: Opacity(
                  opacity: 0.15,
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => ui.Gradient.linear(
                      bounds.centerLeft,
                      bounds.centerRight,
                      const <Color>[Colors.transparent, Colors.blue],
                    ),
                    child: const SizedBox(
                      width: 40,
                      height: 24,
                      child: ColoredBox(color: Colors.red),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final frame = await _capturePixels(tester, boundaryKey);

        expect(
          (
            center: _pixelAt(frame, 20, 12).toARGB32(),
            sourceColorVisible: _containsSaturatedSourcePixel(frame),
          ),
          (center: boneColor.toARGB32(), sourceColorVisible: false),
        );
      },
    );

    testWidgets(
      'when a shader mask descendant repaints while enabled, it should keep propagating skeleton invalidations',
      (tester) async {
        const boundaryKey = ValueKey(
          'skeleton-repainting-shader-mask-boundary',
        );
        const boneColor = Color(0xFF536579);
        final repaint = ValueNotifier<({Color color, double inset})>(
          (color: Colors.green, inset: 0),
        );
        final painter = _MutableGeometryPainter(repaint);
        addTearDown(repaint.dispose);

        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: Skeleton(
              style: const SkeletonStyle(
                color: boneColor,
                radius: Radius.zero,
              ),
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => ui.Gradient.linear(
                  bounds.centerLeft,
                  bounds.centerRight,
                  const <Color>[Colors.red, Colors.blue],
                ),
                child: CustomPaint(
                  size: const Size(40, 24),
                  painter: painter,
                ),
              ),
            ),
          ),
        );
        final renderShaderMask = tester.renderObject<RenderShaderMask>(
          find.byType(ShaderMask),
        );
        final initialPaintCount = painter.paintCount;
        final dirtyAfterInitialPaint = renderShaderMask.debugNeedsPaint;

        repaint.value = (color: Colors.red, inset: 4);
        await tester.pump();
        final firstFrame = await _capturePixels(tester, boundaryKey);
        final firstPaintCount = painter.paintCount;
        final dirtyAfterFirstRepaint = renderShaderMask.debugNeedsPaint;

        repaint.value = (color: Colors.blue, inset: 8);
        await tester.pump();
        final secondFrame = await _capturePixels(tester, boundaryKey);
        final secondPaintCount = painter.paintCount;

        expect(
          (
            initiallyPainted: initialPaintCount > 0,
            dirtyAfterInitialPaint: dirtyAfterInitialPaint,
            firstRepaints: firstPaintCount - initialPaintCount,
            dirtyAfterFirstRepaint: dirtyAfterFirstRepaint,
            firstCenter: _pixelAt(firstFrame, 20, 12).toARGB32(),
            firstEdgeAlpha: _pixelAt(firstFrame, 1, 1).a,
            firstSourceColorVisible: _containsSaturatedSourcePixel(firstFrame),
            secondRepaints: secondPaintCount - firstPaintCount,
            dirtyAfterSecondRepaint: renderShaderMask.debugNeedsPaint,
            secondCenter: _pixelAt(secondFrame, 20, 12).toARGB32(),
            secondEdgeAlpha: _pixelAt(secondFrame, 5, 5).a,
            secondSourceColorVisible: _containsSaturatedSourcePixel(
              secondFrame,
            ),
          ),
          (
            initiallyPainted: true,
            dirtyAfterInitialPaint: false,
            firstRepaints: 1,
            dirtyAfterFirstRepaint: false,
            firstCenter: boneColor.toARGB32(),
            firstEdgeAlpha: 0.0,
            firstSourceColorVisible: false,
            secondRepaints: 1,
            dirtyAfterSecondRepaint: false,
            secondCenter: boneColor.toARGB32(),
            secondEdgeAlpha: 0.0,
            secondSourceColorVisible: false,
          ),
        );
      },
    );

    testWidgets(
      'when a leaf draws an unsupported picture, it should use its bounds as a clean fallback bone',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-picture-boundary');
        const boneColor = Color(0xFF536579);
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 40, 24),
          Paint()..color = Colors.red,
        );
        final picture = recorder.endRecording();
        addTearDown(picture.dispose);

        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: Skeleton(
              style: const SkeletonStyle(
                color: boneColor,
                radius: Radius.zero,
              ),
              child: CustomPaint(
                size: const Size(40, 24),
                painter: _PicturePainter(picture),
              ),
            ),
          ),
        );

        final frame = await _capturePixels(tester, boundaryKey);

        expect(
          (
            center: _pixelAt(frame, 20, 12).toARGB32(),
            sourceColorVisible: _containsSaturatedSourcePixel(frame),
          ),
          (center: boneColor.toARGB32(), sourceColorVisible: false),
        );
      },
    );

    testWidgets(
      'when a leaf appends a source layer, it should suppress the layer and paint a bounds bone',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-appended-layer-boundary');
        const boneColor = Color(0xFF536579);
        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: const Skeleton(
              style: SkeletonStyle(color: boneColor, radius: Radius.zero),
              child: _LayerPaintingLeaf(
                size: Size(40, 24),
                color: Colors.red,
              ),
            ),
          ),
        );

        final frame = await _capturePixels(tester, boundaryKey);

        expect(
          (
            center: _pixelAt(frame, 20, 12).toARGB32(),
            sourceColorVisible: _containsSaturatedSourcePixel(frame),
          ),
          (center: boneColor.toARGB32(), sourceColorVisible: false),
        );
      },
    );

    testWidgets(
      'when one leaf emits several unsupported layers, it should record one fallback bone',
      (tester) async {
        const boundaryKey = ValueKey(
          'skeleton-several-unsupported-layers-boundary',
        );
        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: const Skeleton(
              style: SkeletonStyle(
                effect: _HalfOpacityStaticEffect(),
                radius: Radius.zero,
              ),
              child: _SeveralLayerPaintingLeaf(size: Size(40, 24)),
            ),
          ),
        );

        final frame = await _capturePixels(tester, boundaryKey);

        expect(_pixelAt(frame, 20, 12).a, 128 / 255);
      },
    );

    testWidgets(
      'when several saturated source colors are skeletonized, none should leak into the output pixels',
      (tester) async {
        const boundaryKey = ValueKey('skeleton-source-colors-boundary');
        await tester.pumpWidget(
          _pixelApp(
            boundaryKey: boundaryKey,
            child: const Skeleton(
              style: SkeletonStyle(
                color: Color(0xFF68727D),
                radius: Radius.zero,
              ),
              child: SizedBox(
                width: 120,
                height: 40,
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 40,
                      child: ColoredBox(color: Colors.red),
                    ),
                    SizedBox.square(
                      dimension: 40,
                      child: ColoredBox(color: Colors.green),
                    ),
                    SizedBox.square(
                      dimension: 40,
                      child: ColoredBox(color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final frame = await _capturePixels(tester, boundaryKey);

        expect(_containsSaturatedSourcePixel(frame), isFalse);
      },
    );
  });

  group('Skeleton canvas interception', () {
    testWidgets(
      'when skeletonizing a deep widget tree with layers, it should render without error',
      (tester) async {
        await tester.pumpWidget(
          _app(
            child: const Skeleton(
              child: Column(
                children: [
                  Text('Header'),
                  SizedBox(height: 8),
                  Row(children: [Icon(Icons.star), Text('Rating')]),
                  SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                    child: ColoredBox(
                      color: Colors.blue,
                      child: SizedBox(width: 100, height: 100),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'when skeletonizing Transform widgets, it should render without error',
      (tester) async {
        await tester.pumpWidget(
          _app(
            child: Skeleton(
              child: Transform.scale(
                scale: 0.8,
                child: const Text('Scaled text'),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'when skeletonizing a CircleAvatar, it should render without error',
      (tester) async {
        await tester.pumpWidget(
          _app(
            child: const Skeleton(child: CircleAvatar(child: Text('AB'))),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'when skeletonizing a RotatedBox, it should render without error',
      (tester) async {
        await tester.pumpWidget(
          _app(
            child: const Skeleton(
              child: RotatedBox(quarterTurns: 1, child: Text('Rotated')),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'when skeletonizing an Opacity wrapper, it should render without error',
      (tester) async {
        await tester.pumpWidget(
          _app(
            child: const Skeleton(
              child: Opacity(opacity: 0.5, child: Text('Faded')),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'when skeletonizing a ClipPath widget, it should render without error',
      (tester) async {
        await tester.pumpWidget(
          _app(
            child: const Skeleton(
              child: ClipPath(
                clipper: _TestClipper(),
                child: ColoredBox(
                  color: Colors.blue,
                  child: SizedBox(width: 100, height: 100),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'when skeletonizing an OverflowBox, it should render without error',
      (tester) async {
        await tester.pumpWidget(
          _app(
            child: const Skeleton(
              child: OverflowBox(
                minWidth: 50,
                maxWidth: 200,
                minHeight: 50,
                maxHeight: 200,
                child: Text('Overflow'),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'when skeletonizing a leaf container with color, it should intercept drawRect as a bone',
      (tester) async {
        await tester.pumpWidget(
          _app(
            child: const Skeleton(
              child: SizedBox(
                width: 50,
                height: 50,
                child: ColoredBox(color: Colors.blue),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'when skeletonizing a container with rounded corners, it should intercept drawRRect',
      (tester) async {
        await tester.pumpWidget(
          _app(
            child: const Skeleton(
              child: SizedBox(
                width: 50,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'when skeletonizing a PhysicalModel, it should intercept drawDRRect',
      (tester) async {
        await tester.pumpWidget(
          _app(
            child: const Skeleton(
              child: SizedBox(
                width: 50,
                height: 50,
                child: PhysicalModel(
                  color: Colors.blue,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  child: SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'when skeletonizing an Align with a leaf child, it should intercept leaf draw calls',
      (tester) async {
        await tester.pumpWidget(
          _app(
            child: const Skeleton(
              child: Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: ColoredBox(
                    color: Colors.green,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _PaintCounter extends CustomPainter {
  _PaintCounter({super.repaint});

  int paintCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paintCount += 1;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.blue);
  }

  @override
  bool shouldRepaint(_PaintCounter oldDelegate) => false;
}

class _PicturePainter extends CustomPainter {
  const _PicturePainter(this.picture);

  final ui.Picture picture;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPicture(picture);

  @override
  bool shouldRepaint(_PicturePainter oldDelegate) => false;
}

class _MutableGeometryPainter extends CustomPainter {
  _MutableGeometryPainter(this.geometry) : super(repaint: geometry);

  final ValueNotifier<({Color color, double inset})> geometry;

  int paintCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paintCount += 1;
    final value = geometry.value;
    canvas.drawRect(
      Rect.fromLTWH(
        value.inset,
        value.inset,
        size.width - value.inset * 2,
        size.height - value.inset * 2,
      ),
      Paint()..color = value.color,
    );
  }

  @override
  bool shouldRepaint(_MutableGeometryPainter oldDelegate) => false;
}

class _LayerPaintingLeaf extends LeafRenderObjectWidget {
  const _LayerPaintingLeaf({required this.size, required this.color});

  final Size size;
  final Color color;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderLayerPaintingLeaf(preferredSize: size, color: color);
  }
}

class _SeveralLayerPaintingLeaf extends LeafRenderObjectWidget {
  const _SeveralLayerPaintingLeaf({required this.size});

  final Size size;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSeveralLayerPaintingLeaf(preferredSize: size);
  }
}

class _RenderSeveralLayerPaintingLeaf extends RenderBox {
  _RenderSeveralLayerPaintingLeaf({required this.preferredSize});

  final Size preferredSize;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.constrain(preferredSize);
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.pushLayer(
      OffsetLayer(),
      (context, offset) {},
      offset,
    );
    final bounds = offset & size;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      bounds,
      Paint()..color = Colors.red,
    );
    context.addLayer(
      PictureLayer(bounds)..picture = recorder.endRecording(),
    );
  }
}

class _HalfOpacityStaticEffect extends SkeletonStaticEffectBase {
  const _HalfOpacityStaticEffect();

  @override
  Paint buildPaint({
    required Rect bounds,
    required double t,
    required SkeletonStyle style,
  }) {
    return Paint()..color = const Color(0x80000000);
  }
}

class _RenderLayerPaintingLeaf extends RenderBox {
  _RenderLayerPaintingLeaf({required this.preferredSize, required this.color});

  final LayerHandle<PictureLayer> _pictureLayer = LayerHandle<PictureLayer>();

  final Size preferredSize;
  final Color color;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.constrain(preferredSize);
  }

  @override
  void performLayout() {
    size = computeDryLayout(constraints);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final bounds = offset & size;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(bounds, Paint()..color = color);
    final pictureLayer = PictureLayer(bounds)..picture = recorder.endRecording();
    _pictureLayer.layer = pictureLayer;
    context.addLayer(pictureLayer);
  }

  @override
  void dispose() {
    _pictureLayer.layer = null;
    super.dispose();
  }
}

class _TickingChild extends StatefulWidget {
  const _TickingChild({super.key});

  @override
  State<_TickingChild> createState() => _TickingChildState();
}

class _TickingChildState extends State<_TickingChild> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  int ticks = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(seconds: 1),
          )
          ..addListener(_handleTick)
          ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTick() => ticks += 1;

  @override
  Widget build(BuildContext context) => const SizedBox(width: 40, height: 20);
}

class _TestClipper extends CustomClipper<Path> {
  const _TestClipper();

  @override
  Path getClip(Size size) => Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height));

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
