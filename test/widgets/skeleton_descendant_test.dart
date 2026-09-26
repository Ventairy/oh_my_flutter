import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

const _boneColor = Color(0xFF536579);

MaterialApp _app({required Key boundaryKey, required Widget child}) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: RepaintBoundary(key: boundaryKey, child: child),
      ),
    ),
  );
}

Future<({int height, List<int> pixels, int width})> _capture(
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

bool _containsSourceColor(({int height, List<int> pixels, int width}) frame) {
  for (var offset = 0; offset < frame.pixels.length; offset += 4) {
    final color = Color.fromARGB(
      frame.pixels[offset + 3],
      frame.pixels[offset],
      frame.pixels[offset + 1],
      frame.pixels[offset + 2],
    );
    if (color == Colors.red || color == Colors.green || color == Colors.blue) {
      return true;
    }
  }
  return false;
}

Widget _surface({required Widget child, Color color = Colors.red}) {
  return SizedBox(
    width: 52,
    height: 52,
    child: DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(child: child),
    ),
  );
}

Widget _skeleton(Widget child, {bool enabled = true}) {
  return Skeleton(
    enabled: enabled,
    style: const SkeletonStyle(color: _boneColor, shape: RoundedRectangleBorder()),
    child: child,
  );
}

void main() {
  group('Skeleton', () {
    testWidgets(
      'when a decorated circle contains an icon shape, it should paint one complete circular bone',
      (tester) async {
        const boundaryKey = ValueKey('default-circle-boundary');
        await tester.pumpWidget(
          _app(
            boundaryKey: boundaryKey,
            child: _skeleton(
              _surface(
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        );

        final frame = await _capture(tester, boundaryKey);

        expect(
          (
            outer: _pixelAt(frame, 26, 4).toARGB32(),
            center: _pixelAt(frame, 26, 26).toARGB32(),
            sourceVisible: _containsSourceColor(frame),
          ),
          (
            outer: _boneColor.toARGB32(),
            center: _boneColor.toARGB32(),
            sourceVisible: false,
          ),
        );
      },
    );
  });

  group('SkeletonDescendant', () {
    testWidgets(
      'when paintAsBone is used, it should paint the first visible descendant and stop before its child',
      (tester) async {
        const boundaryKey = ValueKey('paint-as-bone-boundary');
        await tester.pumpWidget(
          _app(
            boundaryKey: boundaryKey,
            child: _skeleton(
              SkeletonDescendant(
                behavior: const SkeletonDescendantBehavior.paintAsBone(),
                child: _surface(
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: ColoredBox(color: Colors.blue),
                  ),
                ),
              ),
            ),
          ),
        );

        final frame = await _capture(tester, boundaryKey);

        expect(
          (
            outer: _pixelAt(frame, 26, 4).toARGB32(),
            center: _pixelAt(frame, 26, 26).toARGB32(),
            sourceVisible: _containsSourceColor(frame),
          ),
          (
            outer: _boneColor.toARGB32(),
            center: _boneColor.toARGB32(),
            sourceVisible: false,
          ),
        );
      },
    );

    testWidgets(
      'when deferToChildren is used, it should suppress the first visible descendant and skeletonize its child',
      (tester) async {
        const boundaryKey = ValueKey('defer-to-children-boundary');
        await tester.pumpWidget(
          _app(
            boundaryKey: boundaryKey,
            child: _skeleton(
              SkeletonDescendant(
                behavior: const SkeletonDescendantBehavior.deferToChildren(),
                child: _surface(
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: ColoredBox(color: Colors.blue),
                  ),
                ),
              ),
            ),
          ),
        );

        final frame = await _capture(tester, boundaryKey);

        expect(
          (
            outerAlpha: _pixelAt(frame, 26, 4).a,
            center: _pixelAt(frame, 26, 26).toARGB32(),
            sourceVisible: _containsSourceColor(frame),
          ),
          (
            outerAlpha: 0.0,
            center: _boneColor.toARGB32(),
            sourceVisible: false,
          ),
        );
      },
    );

    testWidgets(
      'when hide is used, it should retain layout without painting the subtree',
      (tester) async {
        const boundaryKey = ValueKey('hide-boundary');
        await tester.pumpWidget(
          _app(
            boundaryKey: boundaryKey,
            child: _skeleton(
              SkeletonDescendant(
                behavior: const SkeletonDescendantBehavior.hide(),
                child: _surface(
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: ColoredBox(color: Colors.blue),
                  ),
                ),
              ),
            ),
          ),
        );

        final frame = await _capture(tester, boundaryKey);

        expect(
          (
            size: tester.getSize(find.byType(SkeletonDescendant)),
            outerAlpha: _pixelAt(frame, 26, 4).a,
            centerAlpha: _pixelAt(frame, 26, 26).a,
          ),
          (size: const Size(52, 52), outerAlpha: 0.0, centerAlpha: 0.0),
        );
      },
    );

    testWidgets(
      'when Skeleton is disabled, it should render the annotated subtree normally',
      (tester) async {
        const boundaryKey = ValueKey('disabled-boundary');
        await tester.pumpWidget(
          _app(
            boundaryKey: boundaryKey,
            child: _skeleton(
              SkeletonDescendant(
                behavior: const SkeletonDescendantBehavior.hide(),
                child: _surface(
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: ColoredBox(color: Colors.blue),
                  ),
                ),
              ),
              enabled: false,
            ),
          ),
        );

        final frame = await _capture(tester, boundaryKey);

        expect(
          (
            outer: _pixelAt(frame, 26, 4).toARGB32(),
            center: _pixelAt(frame, 26, 26).toARGB32(),
          ),
          (outer: Colors.red.toARGB32(), center: Colors.blue.toARGB32()),
        );
      },
    );

    testWidgets(
      'when no Skeleton ancestor is enabled, it should render the annotated subtree normally',
      (tester) async {
        const boundaryKey = ValueKey('outside-skeleton-boundary');
        await tester.pumpWidget(
          _app(
            boundaryKey: boundaryKey,
            child: SkeletonDescendant(
              behavior: const SkeletonDescendantBehavior.hide(),
              child: _surface(
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: ColoredBox(color: Colors.blue),
                ),
              ),
            ),
          ),
        );

        final frame = await _capture(tester, boundaryKey);

        expect(
          (
            outer: _pixelAt(frame, 26, 4).toARGB32(),
            center: _pixelAt(frame, 26, 26).toARGB32(),
          ),
          (
            outer: Colors.red.toARGB32(),
            center: Colors.blue.toARGB32(),
          ),
        );
      },
    );

    testWidgets(
      'when paintAsBone contains a hide annotation, it should terminate before the nested behavior',
      (tester) async {
        const boundaryKey = ValueKey('terminal-paint-boundary');
        await tester.pumpWidget(
          _app(
            boundaryKey: boundaryKey,
            child: _skeleton(
              SkeletonDescendant(
                behavior: const SkeletonDescendantBehavior.paintAsBone(),
                child: _surface(
                  child: const SkeletonDescendant(
                    behavior: SkeletonDescendantBehavior.hide(),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: ColoredBox(color: Colors.blue),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final frame = await _capture(tester, boundaryKey);

        expect(
          (
            outer: _pixelAt(frame, 26, 4).toARGB32(),
            center: _pixelAt(frame, 26, 26).toARGB32(),
          ),
          (
            outer: _boneColor.toARGB32(),
            center: _boneColor.toARGB32(),
          ),
        );
      },
    );

    testWidgets(
      'when hide contains a paintAsBone annotation, it should terminate the complete branch',
      (tester) async {
        const boundaryKey = ValueKey('terminal-hide-boundary');
        await tester.pumpWidget(
          _app(
            boundaryKey: boundaryKey,
            child: _skeleton(
              SkeletonDescendant(
                behavior: const SkeletonDescendantBehavior.hide(),
                child: _surface(
                  child: const SkeletonDescendant(
                    behavior: SkeletonDescendantBehavior.paintAsBone(),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: ColoredBox(color: Colors.blue),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final frame = await _capture(tester, boundaryKey);

        expect(
          (
            outerAlpha: _pixelAt(frame, 26, 4).a,
            centerAlpha: _pixelAt(frame, 26, 26).a,
          ),
          (outerAlpha: 0.0, centerAlpha: 0.0),
        );
      },
    );

    testWidgets(
      'when paintAsBone finds no visible paint, it should use the annotated layout bounds',
      (tester) async {
        const boundaryKey = ValueKey('bounds-fallback-boundary');
        await tester.pumpWidget(
          _app(
            boundaryKey: boundaryKey,
            child: _skeleton(
              const SkeletonDescendant(
                behavior: SkeletonDescendantBehavior.paintAsBone(),
                child: SizedBox(width: 52, height: 52),
              ),
            ),
          ),
        );

        final frame = await _capture(tester, boundaryKey);

        expect(
          (
            corner: _pixelAt(frame, 1, 1).toARGB32(),
            center: _pixelAt(frame, 26, 26).toARGB32(),
          ),
          (
            corner: _boneColor.toARGB32(),
            center: _boneColor.toARGB32(),
          ),
        );
      },
    );

    testWidgets(
      'when deferToChildren annotations nest, they should defer successive painted levels',
      (tester) async {
        const boundaryKey = ValueKey('nested-defer-boundary');
        await tester.pumpWidget(
          _app(
            boundaryKey: boundaryKey,
            child: _skeleton(
              SkeletonDescendant(
                behavior: const SkeletonDescendantBehavior.deferToChildren(),
                child: _surface(
                  child: SkeletonDescendant(
                    behavior: const SkeletonDescendantBehavior.deferToChildren(),
                    child: _surface(
                      color: Colors.green,
                      child: const SizedBox(
                        width: 12,
                        height: 12,
                        child: ColoredBox(color: Colors.blue),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final frame = await _capture(tester, boundaryKey);

        expect(
          (
            outerAlpha: _pixelAt(frame, 26, 4).a,
            middleAlpha: _pixelAt(frame, 26, 10).a,
            center: _pixelAt(frame, 26, 26).toARGB32(),
            sourceVisible: _containsSourceColor(frame),
          ),
          (
            outerAlpha: 0.0,
            middleAlpha: 0.0,
            center: _boneColor.toARGB32(),
            sourceVisible: false,
          ),
        );
      },
    );

    testWidgets(
      'when deferToChildren wraps a repaint boundary, it should bypass the boundary and skeletonize below it',
      (tester) async {
        const boundaryKey = ValueKey('deferred-repaint-boundary');
        await tester.pumpWidget(
          _app(
            boundaryKey: boundaryKey,
            child: _skeleton(
              SkeletonDescendant(
                behavior: const SkeletonDescendantBehavior.deferToChildren(),
                child: RepaintBoundary(
                  child: _surface(
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: ColoredBox(color: Colors.blue),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        final frame = await _capture(tester, boundaryKey);

        expect(
          (
            outerAlpha: _pixelAt(frame, 26, 4).a,
            center: _pixelAt(frame, 26, 26).toARGB32(),
          ),
          (outerAlpha: 0.0, center: _boneColor.toARGB32()),
        );
      },
    );

    testWidgets(
      'when behavior changes at runtime, it should repaint the retained skeleton geometry',
      (tester) async {
        const boundaryKey = ValueKey('runtime-behavior-boundary');
        var behavior = const SkeletonDescendantBehavior.hide();
        late StateSetter update;
        await tester.pumpWidget(
          _app(
            boundaryKey: boundaryKey,
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return _skeleton(
                  SkeletonDescendant(
                    behavior: behavior,
                    child: _surface(child: const SizedBox.shrink()),
                  ),
                );
              },
            ),
          ),
        );
        final hiddenFrame = await _capture(tester, boundaryKey);

        update(() => behavior = const SkeletonDescendantBehavior.paintAsBone());
        await tester.pump();
        final paintedFrame = await _capture(tester, boundaryKey);

        expect(
          (
            hiddenAlpha: _pixelAt(hiddenFrame, 26, 26).a,
            painted: _pixelAt(paintedFrame, 26, 26).toARGB32(),
          ),
          (hiddenAlpha: 0.0, painted: _boneColor.toARGB32()),
        );
      },
    );

    testWidgets(
      'when siblings use different behaviors, each should control only its own branch',
      (tester) async {
        const boundaryKey = ValueKey('sibling-behaviors-boundary');
        await tester.pumpWidget(
          _app(
            boundaryKey: boundaryKey,
            child: _skeleton(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SkeletonDescendant(
                    behavior: const SkeletonDescendantBehavior.hide(),
                    child: _surface(child: const SizedBox.shrink()),
                  ),
                  SkeletonDescendant(
                    behavior: const SkeletonDescendantBehavior.paintAsBone(),
                    child: _surface(child: const SizedBox.shrink()),
                  ),
                ],
              ),
            ),
          ),
        );

        final frame = await _capture(tester, boundaryKey);

        expect(
          (
            hiddenAlpha: _pixelAt(frame, 26, 26).a,
            painted: _pixelAt(frame, 78, 26).toARGB32(),
          ),
          (hiddenAlpha: 0.0, painted: _boneColor.toARGB32()),
        );
      },
    );

    testWidgets(
      'when a runtime behavior change removes every bone, it should stop animated frames',
      (tester) async {
        var behavior = const SkeletonDescendantBehavior.paintAsBone();
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Skeleton(
                  style: const SkeletonStyle(
                    effect: SkeletonShimmerEffect(),
                  ),
                  child: SkeletonDescendant(
                    behavior: behavior,
                    child: const ColoredBox(color: Colors.red),
                  ),
                );
              },
            ),
          ),
        );

        update(() => behavior = const SkeletonDescendantBehavior.hide());
        await tester.pump();

        expect(tester.binding.transientCallbackCount, 0);
      },
    );

    testWidgets(
      'when one branch builds a custom bone, it should paint that widget beside automatic bones',
      (tester) async {
        const boundaryKey = ValueKey('custom-bone-boundary');
        await tester.pumpWidget(
          _app(
            boundaryKey: boundaryKey,
            child: _skeleton(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SkeletonDescendant(
                    behavior: SkeletonDescendantBehavior.paintAsBone(
                      builder: (_) => const ColoredBox(
                        key: ValueKey('custom-bone'),
                        color: Colors.purple,
                      ),
                    ),
                    child: _surface(child: const SizedBox.shrink()),
                  ),
                  _surface(child: const SizedBox.shrink()),
                ],
              ),
            ),
          ),
        );

        final frame = await _capture(tester, boundaryKey);

        expect(
          (
            custom: _pixelAt(frame, 26, 26).toARGB32(),
            automatic: _pixelAt(frame, 78, 26).toARGB32(),
            customSize: tester.getSize(find.byKey(const ValueKey('custom-bone'))),
          ),
          (custom: Colors.purple.toARGB32(), automatic: _boneColor.toARGB32(), customSize: const Size(52, 52)),
        );
      },
    );

    testWidgets(
      'when loading changes, it should retain the original child and remove the custom bone',
      (tester) async {
        const childKey = ValueKey('retained-content');
        var enabled = true;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Skeleton(
                  enabled: enabled,
                  child: SkeletonDescendant(
                    behavior: SkeletonDescendantBehavior.paintAsBone(
                      builder: (_) => const ColoredBox(color: Colors.purple),
                    ),
                    child: StatefulBuilder(
                      key: childKey,
                      builder: (context, setState) => const SizedBox(
                        width: 52,
                        height: 52,
                        child: ColoredBox(color: Colors.red),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        final originalElement = tester.element(find.byKey(childKey));

        update(() => enabled = false);
        await tester.pump();

        expect(
          (
            childRetained: identical(tester.element(find.byKey(childKey)), originalElement),
            customRemoved: find
                .byType(ColoredBox)
                .evaluate()
                .where((element) => (element.widget as ColoredBox).color == Colors.purple)
                .isEmpty,
          ),
          (childRetained: true, customRemoved: true),
        );
      },
    );

    testWidgets(
      'when the custom bone changes, it should repaint its supplied appearance',
      (tester) async {
        const boundaryKey = ValueKey('updated-custom-bone-boundary');
        var customColor = Colors.purple;
        late StateSetter update;
        await tester.pumpWidget(
          _app(
            boundaryKey: boundaryKey,
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return _skeleton(
                  SkeletonDescendant(
                    behavior: SkeletonDescendantBehavior.paintAsBone(
                      builder: (_) => ColoredBox(color: customColor),
                    ),
                    child: _surface(child: const SizedBox.shrink()),
                  ),
                );
              },
            ),
          ),
        );
        final before = await _capture(tester, boundaryKey);

        update(() => customColor = Colors.orange);
        await tester.pump();
        final after = await _capture(tester, boundaryKey);

        expect(
          (before: _pixelAt(before, 26, 26).toARGB32(), after: _pixelAt(after, 26, 26).toARGB32()),
          (before: Colors.purple.toARGB32(), after: Colors.orange.toARGB32()),
        );
      },
    );

    testWidgets(
      'when loading is enabled, it should hide custom bone interactions and content semantics',
      (tester) async {
        final semantics = tester.ensureSemantics();
        var enabled = true;
        var taps = 0;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Skeleton(
                  enabled: enabled,
                  semanticsLabel: 'Loading action',
                  child: SkeletonDescendant(
                    behavior: SkeletonDescendantBehavior.paintAsBone(
                      builder: (_) => SizedBox(
                        width: 120,
                        height: 48,
                        child: TextButton(
                          key: const ValueKey('custom-bone-button'),
                          onPressed: () => taps += 1,
                          child: const Text('Bone action'),
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: 120,
                      height: 48,
                      child: TextButton(
                        key: const ValueKey('content-button'),
                        onPressed: () => taps += 1,
                        child: const Text('Content action'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.byKey(const ValueKey('custom-bone-button')), warnIfMissed: false);
        final loadingResult = (
          taps: taps,
          loadingLabel: find.bySemanticsLabel('Loading action').evaluate().length,
          boneLabel: find.bySemanticsLabel('Bone action').evaluate().length,
          contentLabel: find.bySemanticsLabel('Content action').evaluate().length,
        );
        update(() => enabled = false);
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('content-button')));

        expect(
          (loading: loadingResult, contentTaps: taps),
          (
            loading: (taps: 0, loadingLabel: 1, boneLabel: 0, contentLabel: 0),
            contentTaps: 1,
          ),
        );
        semantics.dispose();
      },
    );

    testWidgets(
      'when crossfade reveals content, it should blend the custom bone and retained child',
      (tester) async {
        const boundaryKey = ValueKey('custom-bone-transition-boundary');
        var enabled = true;
        late StateSetter update;
        await tester.pumpWidget(
          _app(
            boundaryKey: boundaryKey,
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Skeleton(
                  enabled: enabled,
                  transition: const SkeletonTransition.crossfade(duration: Duration(milliseconds: 100)),
                  child: SkeletonDescendant(
                    behavior: SkeletonDescendantBehavior.paintAsBone(
                      builder: (_) => const ColoredBox(color: Colors.purple),
                    ),
                    child: const SizedBox(width: 52, height: 52, child: ColoredBox(color: Colors.red)),
                  ),
                );
              },
            ),
          ),
        );
        final loadingFrame = await _capture(tester, boundaryKey);

        update(() => enabled = false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final middleFrame = await _capture(tester, boundaryKey);
        await tester.pump(const Duration(milliseconds: 50));
        final contentFrame = await _capture(tester, boundaryKey);

        expect(
          (
            loading: _pixelAt(loadingFrame, 26, 26).toARGB32(),
            middleChanges: _pixelAt(middleFrame, 26, 26).toARGB32() != Colors.purple.toARGB32(),
            content: _pixelAt(contentFrame, 26, 26).toARGB32(),
          ),
          (loading: Colors.purple.toARGB32(), middleChanges: true, content: Colors.red.toARGB32()),
        );
      },
    );

    testWidgets(
      'when a custom bone contains a Morph, it should connect to a matching appearance',
      (tester) async {
        final target = MorphTarget(tag: #customSkeletonBone);
        var showDestination = false;
        var flightsStarted = 0;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [MorphNavigatorObserver()],
            home: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return Stack(
                  children: [
                    if (!showDestination)
                      Skeleton(
                        child: SkeletonDescendant(
                          behavior: SkeletonDescendantBehavior.paintAsBone(
                            builder: (_) => Morph(
                              targets: [target],
                              onStart: () => flightsStarted += 1,
                              child: const ColoredBox(color: Colors.purple),
                            ),
                          ),
                          child: const SizedBox(width: 52, height: 52),
                        ),
                      ),
                    if (showDestination)
                      Positioned(
                        top: 100,
                        left: 100,
                        child: Morph(
                          targets: [target],
                          child: const SizedBox(width: 24, height: 24, child: ColoredBox(color: Colors.green)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );

        update(() => showDestination = true);
        await tester.pump();

        expect(flightsStarted, 1);
        await tester.pumpAndSettle();
      },
    );
  });
}
