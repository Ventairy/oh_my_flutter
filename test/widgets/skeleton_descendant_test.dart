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
    style: const SkeletonStyle(color: _boneColor, radius: Radius.zero),
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
                behavior: SkeletonDescendantBehavior.paintAsBone,
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
                behavior: SkeletonDescendantBehavior.deferToChildren,
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
                behavior: SkeletonDescendantBehavior.hide,
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
                behavior: SkeletonDescendantBehavior.hide,
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
              behavior: SkeletonDescendantBehavior.hide,
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
                behavior: SkeletonDescendantBehavior.paintAsBone,
                child: _surface(
                  child: const SkeletonDescendant(
                    behavior: SkeletonDescendantBehavior.hide,
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
                behavior: SkeletonDescendantBehavior.hide,
                child: _surface(
                  child: const SkeletonDescendant(
                    behavior: SkeletonDescendantBehavior.paintAsBone,
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
                behavior: SkeletonDescendantBehavior.paintAsBone,
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
                behavior: SkeletonDescendantBehavior.deferToChildren,
                child: _surface(
                  child: SkeletonDescendant(
                    behavior: SkeletonDescendantBehavior.deferToChildren,
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
                behavior: SkeletonDescendantBehavior.deferToChildren,
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
        var behavior = SkeletonDescendantBehavior.hide;
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

        update(() => behavior = SkeletonDescendantBehavior.paintAsBone);
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
                    behavior: SkeletonDescendantBehavior.hide,
                    child: _surface(child: const SizedBox.shrink()),
                  ),
                  SkeletonDescendant(
                    behavior: SkeletonDescendantBehavior.paintAsBone,
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
        var behavior = SkeletonDescendantBehavior.paintAsBone;
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

        update(() => behavior = SkeletonDescendantBehavior.hide);
        await tester.pump();

        expect(tester.binding.transientCallbackCount, 0);
      },
    );
  });
}
