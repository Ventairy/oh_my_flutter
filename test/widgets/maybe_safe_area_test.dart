import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

const _viewSize = Size(300, 600);
const _viewPadding = EdgeInsets.fromLTRB(12, 40, 16, 20);

Widget _testView({
  required Widget child,
  EdgeInsets padding = _viewPadding,
}) {
  return MediaQuery(
    data: const MediaQueryData(size: _viewSize).copyWith(padding: padding),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox.fromSize(size: _viewSize, child: child),
      ),
    ),
  );
}

Widget _testApp({
  required Widget child,
  EdgeInsets padding = _viewPadding,
}) {
  return MaterialApp(
    builder: (context, navigator) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: padding,
          viewPadding: padding,
        ),
        child: navigator!,
      );
    },
    home: SizedBox.expand(child: child),
  );
}

void _useTestView(WidgetTester tester) {
  tester.view.physicalSize = _viewSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Finder _morphOverlay() {
  return find.byWidgetPredicate(
    (widget) => widget.runtimeType.toString() == '_MorphOverlay',
  );
}

void main() {
  group('MaybeSafeArea', () {
    testWidgets(
      'when the child overlaps the top unsafe area, it should paint at the avoided position on the first frame',
      (tester) async {
        const childKey = ValueKey('child');
        await tester.pumpWidget(
          _testView(
            child: const Stack(
              children: [
                Positioned(
                  left: 100,
                  child: MaybeSafeArea(
                    child: SizedBox(key: childKey, width: 40, height: 20),
                  ),
                ),
              ],
            ),
          ),
        );
        final firstFramePosition = tester.getTopLeft(find.byKey(childKey));
        await tester.pump();
        expect(
          (firstFramePosition, tester.getTopLeft(find.byKey(childKey))),
          (const Offset(100, 40), const Offset(100, 40)),
        );
      },
    );

    testWidgets(
      'when an ancestor skips paint, it should still report the avoided transform',
      (tester) async {
        const childKey = ValueKey('unpainted-child');
        await tester.pumpWidget(
          _testView(
            child: const Stack(
              children: [
                Positioned(
                  left: 100,
                  child: Opacity(
                    opacity: 0,
                    child: MaybeSafeArea(
                      left: false,
                      right: false,
                      bottom: false,
                      child: SizedBox(
                        key: childKey,
                        width: 40,
                        height: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        expect(
          tester.getTopLeft(find.byKey(childKey, skipOffstage: false)),
          const Offset(100, 40),
        );
      },
    );

    testWidgets(
      'when the child overlaps the bottom unsafe area, it should paint at the avoided position on the first frame',
      (tester) async {
        const childKey = ValueKey('child');
        await tester.pumpWidget(
          _testView(
            child: const Stack(
              children: [
                Positioned(
                  left: 100,
                  bottom: 0,
                  child: MaybeSafeArea(
                    child: SizedBox(key: childKey, width: 40, height: 20),
                  ),
                ),
              ],
            ),
          ),
        );
        final firstFramePosition = tester.getTopLeft(find.byKey(childKey));
        await tester.pump();

        expect(
          (firstFramePosition, tester.getTopLeft(find.byKey(childKey))),
          (const Offset(100, 560), const Offset(100, 560)),
        );
      },
    );

    testWidgets(
      'when the child is in the middle of the view, it should not add padding',
      (tester) async {
        const childKey = ValueKey('child');
        await tester.pumpWidget(
          _testView(
            child: const Stack(
              children: [
                Positioned(
                  left: 100,
                  top: 200,
                  child: MaybeSafeArea(
                    child: SizedBox(key: childKey, width: 40, height: 20),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(tester.getTopLeft(find.byKey(childKey)), const Offset(100, 200));
      },
    );

    testWidgets(
      'when the child moves into and out of an unsafe area, it should preserve its visible position while adapting',
      (tester) async {
        const childKey = ValueKey('child');
        late StateSetter rebuild;
        var top = 200.0;
        await tester.pumpWidget(
          _testView(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Stack(
                  children: [
                    Positioned(
                      left: 100,
                      top: top,
                      child: const MaybeSafeArea(
                        child: SizedBox(key: childKey, width: 40, height: 20),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pump();
        rebuild(() => top = 0);
        await tester.pump();
        final enteringPosition = tester.getTopLeft(find.byKey(childKey));
        await tester.pump();
        final enteredSettledPosition = tester.getTopLeft(find.byKey(childKey));
        rebuild(() => top = 200);
        await tester.pump();
        final leavingPosition = tester.getTopLeft(find.byKey(childKey));
        await tester.pump();

        expect(
          (
            enteringPosition,
            enteredSettledPosition,
            tester.getTopLeft(find.byKey(childKey)),
            leavingPosition,
          ),
          (
            const Offset(100, 40),
            const Offset(100, 40),
            const Offset(100, 200),
            const Offset(100, 200),
          ),
        );
      },
    );

    testWidgets(
      'when the child overlaps the left unsafe area, it should paint at the avoided position on the first frame',
      (tester) async {
        const childKey = ValueKey('child');
        await tester.pumpWidget(
          _testView(
            child: const Stack(
              children: [
                Positioned(
                  top: 100,
                  child: MaybeSafeArea(
                    child: SizedBox(key: childKey, width: 40, height: 20),
                  ),
                ),
              ],
            ),
          ),
        );
        final firstFramePosition = tester.getTopLeft(find.byKey(childKey));
        await tester.pump();

        expect(
          (firstFramePosition, tester.getTopLeft(find.byKey(childKey))),
          (const Offset(12, 100), const Offset(12, 100)),
        );
      },
    );

    testWidgets(
      'when the child overlaps the right unsafe area, it should paint at the avoided position on the first frame',
      (tester) async {
        const childKey = ValueKey('child');
        await tester.pumpWidget(
          _testView(
            child: const Stack(
              children: [
                Positioned(
                  top: 100,
                  right: 0,
                  child: MaybeSafeArea(
                    child: SizedBox(key: childKey, width: 40, height: 20),
                  ),
                ),
              ],
            ),
          ),
        );
        final firstFramePosition = tester.getTopLeft(find.byKey(childKey));
        await tester.pump();

        expect(
          (firstFramePosition, tester.getTopLeft(find.byKey(childKey))),
          (const Offset(244, 100), const Offset(244, 100)),
        );
      },
    );

    testWidgets(
      'when the child overlaps a corner, it should avoid both unsafe edges',
      (tester) async {
        const childKey = ValueKey('child');
        await tester.pumpWidget(
          _testView(
            child: const Stack(
              children: [
                MaybeSafeArea(
                  child: SizedBox(key: childKey, width: 40, height: 20),
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(tester.getTopLeft(find.byKey(childKey)), const Offset(12, 40));
      },
    );

    testWidgets(
      'when the child partially overlaps an unsafe area, it should move only enough to clear it',
      (tester) async {
        const childKey = ValueKey('child');
        await tester.pumpWidget(
          _testView(
            child: const Stack(
              children: [
                Positioned(
                  left: 100,
                  top: 30,
                  child: MaybeSafeArea(
                    child: SizedBox(key: childKey, width: 40, height: 20),
                  ),
                ),
              ],
            ),
          ),
        );
        final firstFramePosition = tester.getTopLeft(find.byKey(childKey));
        await tester.pump();

        expect(
          (firstFramePosition, tester.getTopLeft(find.byKey(childKey))),
          (const Offset(100, 40), const Offset(100, 40)),
        );
      },
    );

    testWidgets(
      'when the child only touches an unsafe boundary, it should not add padding',
      (tester) async {
        const childKey = ValueKey('child');
        await tester.pumpWidget(
          _testView(
            child: const Stack(
              children: [
                Positioned(
                  left: 100,
                  top: 40,
                  child: MaybeSafeArea(
                    child: SizedBox(key: childKey, width: 40, height: 20),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(tester.getTopLeft(find.byKey(childKey)), const Offset(100, 40));
      },
    );

    testWidgets(
      'when each overlapping edge is disabled, it should leave every corresponding edge unchanged',
      (tester) async {
        const leftChildKey = ValueKey('left-child');
        const topChildKey = ValueKey('top-child');
        const rightChildKey = ValueKey('right-child');
        const bottomChildKey = ValueKey('bottom-child');
        await tester.pumpWidget(
          _testView(
            child: const Stack(
              children: [
                Positioned(
                  top: 100,
                  child: MaybeSafeArea(
                    left: false,
                    child: SizedBox(key: leftChildKey, width: 40, height: 20),
                  ),
                ),
                Positioned(
                  left: 100,
                  child: MaybeSafeArea(
                    top: false,
                    child: SizedBox(key: topChildKey, width: 40, height: 20),
                  ),
                ),
                Positioned(
                  top: 200,
                  right: 0,
                  child: MaybeSafeArea(
                    right: false,
                    child: SizedBox(key: rightChildKey, width: 40, height: 20),
                  ),
                ),
                Positioned(
                  left: 100,
                  bottom: 0,
                  child: MaybeSafeArea(
                    bottom: false,
                    child: SizedBox(key: bottomChildKey, width: 40, height: 20),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(
          (
            tester.getTopLeft(find.byKey(leftChildKey)),
            tester.getTopLeft(find.byKey(topChildKey)),
            tester.getTopLeft(find.byKey(rightChildKey)),
            tester.getTopLeft(find.byKey(bottomChildKey)),
          ),
          (
            const Offset(0, 100),
            const Offset(100, 0),
            const Offset(260, 200),
            const Offset(100, 580),
          ),
        );
      },
    );

    testWidgets(
      'when MaybeSafeArea widgets are nested, it should avoid each unsafe edge only once',
      (tester) async {
        const childKey = ValueKey('child');
        await tester.pumpWidget(
          _testView(
            child: const Stack(
              children: [
                Positioned(
                  child: MaybeSafeArea(
                    child: MaybeSafeArea(
                      child: SizedBox(key: childKey, width: 40, height: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        final firstFramePosition = tester.getTopLeft(find.byKey(childKey));
        await tester.pump();

        expect(
          (firstFramePosition, tester.getTopLeft(find.byKey(childKey))),
          (const Offset(12, 40), const Offset(12, 40)),
        );
      },
    );

    testWidgets(
      'when media padding changes at runtime, it should adapt on the changed frame without a settling jump',
      (tester) async {
        const childKey = ValueKey('child');
        late StateSetter rebuild;
        var padding = EdgeInsets.zero;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return _testView(
                padding: padding,
                child: const Stack(
                  children: [
                    Positioned(
                      left: 100,
                      child: MaybeSafeArea(
                        left: false,
                        right: false,
                        bottom: false,
                        child: SizedBox(key: childKey, width: 40, height: 20),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
        await tester.pump();
        rebuild(() => padding = _viewPadding);
        await tester.pump();
        final activatedPosition = tester.getTopLeft(find.byKey(childKey));
        await tester.pump();
        final activatedSettledPosition = tester.getTopLeft(find.byKey(childKey));
        rebuild(() => padding = EdgeInsets.zero);
        await tester.pump();
        final deactivatedPosition = tester.getTopLeft(find.byKey(childKey));
        await tester.pump();

        expect(
          (
            activatedPosition,
            activatedSettledPosition,
            deactivatedPosition,
            tester.getTopLeft(find.byKey(childKey)),
          ),
          (
            const Offset(100, 40),
            const Offset(100, 40),
            const Offset(100, 0),
            const Offset(100, 0),
          ),
        );
      },
    );

    testWidgets(
      'when the view DPR changes, it should preserve the logical avoided position',
      (tester) async {
        const childKey = ValueKey('child');
        tester.view.physicalSize = _viewSize * 2.5;
        tester.view.devicePixelRatio = 2.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _testApp(
            child: const Stack(
              children: [
                Positioned(
                  left: 100,
                  child: MaybeSafeArea(
                    child: SizedBox(key: childKey, width: 40, height: 20),
                  ),
                ),
              ],
            ),
          ),
        );
        final fractionalPosition = tester.getTopLeft(find.byKey(childKey));
        tester.view.physicalSize = _viewSize * 1.25;
        tester.view.devicePixelRatio = 1.25;
        await tester.pump();
        final changedPosition = tester.getTopLeft(find.byKey(childKey));
        await tester.pump();

        expect(
          (
            fractionalPosition,
            changedPosition,
            tester.getTopLeft(find.byKey(childKey)),
          ),
          (
            const Offset(100, 40),
            const Offset(100, 40),
            const Offset(100, 40),
          ),
        );
      },
    );

    testWidgets(
      'when the view has no unsafe padding, it should leave an edge child unchanged',
      (tester) async {
        const childKey = ValueKey('child');
        await tester.pumpWidget(
          _testView(
            padding: EdgeInsets.zero,
            child: const MaybeSafeArea(
              child: SizedBox(key: childKey, width: 40, height: 20),
            ),
          ),
        );
        await tester.pump();

        expect(tester.getTopLeft(find.byKey(childKey)), Offset.zero);
      },
    );

    testWidgets(
      'when an ancestor consumes an unsafe edge, it should not avoid that edge again',
      (tester) async {
        const childKey = ValueKey('child');
        await tester.pumpWidget(
          _testView(
            child: Builder(
              builder: (context) {
                return MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  child: const MaybeSafeArea(
                    left: false,
                    right: false,
                    bottom: false,
                    child: SizedBox(key: childKey, width: 40, height: 20),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();

        expect(tester.getTopLeft(find.byKey(childKey)), Offset.zero);
      },
    );

    testWidgets(
      'when the widget is larger than the safe region, it should not change its position',
      (tester) async {
        const childKey = ValueKey('child');
        await tester.pumpWidget(
          _testView(
            child: const MaybeSafeArea(
              child: SizedBox.expand(key: childKey),
            ),
          ),
        );
        final firstFrameRect = tester.getRect(find.byKey(childKey));
        await tester.pump();

        expect(
          (firstFrameRect, tester.getRect(find.byKey(childKey))),
          (
            const Rect.fromLTRB(0, 0, 300, 600),
            const Rect.fromLTRB(0, 0, 300, 600),
          ),
        );
      },
    );

    testWidgets(
      'when the widget is larger than the safe region, it should reject hits clipped by unsafe edges',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _testView(
            child: MaybeSafeArea(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps += 1,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
        await tester.tapAt(const Offset(150, 20));
        await tester.tapAt(const Offset(150, 100));

        expect(taps, 1);
      },
    );

    testWidgets(
      'when oversized paint reaches unsafe edges, it should clip those pixels on the first frame',
      (tester) async {
        const boundaryKey = ValueKey('boundary');
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: _testView(
              child: const ColoredBox(
                color: Color(0xFF0000FF),
                child: MaybeSafeArea(
                  child: ColoredBox(color: Color(0xFFFF0000)),
                ),
              ),
            ),
          ),
        );
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        final pixels = await tester.runAsync(() async {
          final image = await boundary.toImage();
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            final unsafePixel = 20 * image.width * 4 + 150 * 4;
            final safePixel = 100 * image.width * 4 + 150 * 4;
            return (
              bytes!.getUint32(unsafePixel),
              bytes.getUint32(safePixel),
            );
          } finally {
            image.dispose();
          }
        });

        expect(
          pixels,
          (0x0000FFFF, 0xFF0000FF),
        );
      },
    );

    testWidgets(
      'when an edge is avoided, it should leave descendant media padding unchanged',
      (tester) async {
        EdgeInsets? descendantPadding;
        await tester.pumpWidget(
          _testView(
            child: MaybeSafeArea(
              child: Builder(
                builder: (context) {
                  descendantPadding = MediaQuery.paddingOf(context);
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        );
        await tester.pump();

        expect(descendantPadding, _viewPadding);
      },
    );

    testWidgets(
      'when media padding changes, it should update semantics geometry in the same frame',
      (tester) async {
        const semanticsKey = ValueKey('semantics');
        final semantics = tester.ensureSemantics();
        late StateSetter rebuild;
        var padding = EdgeInsets.zero;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return _testView(
                padding: padding,
                child: Stack(
                  children: [
                    Positioned(
                      left: 100,
                      child: MaybeSafeArea(
                        left: false,
                        right: false,
                        bottom: false,
                        child: Semantics(
                          key: semanticsKey,
                          container: true,
                          label: 'Control',
                          child: const SizedBox(width: 40, height: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
        final initialNode = tester.getSemantics(find.byKey(semanticsKey));
        final initialTop = initialNode.transform?.getTranslation().y ?? 0;
        rebuild(() => padding = _viewPadding);
        await tester.pump();
        final updatedNode = tester.getSemantics(find.byKey(semanticsKey));
        final updatedTop = updatedNode.transform?.getTranslation().y ?? 0;
        semantics.dispose();

        expect(
          (initialTop, updatedTop),
          (0, 40 * tester.view.devicePixelRatio),
        );
      },
    );

    testWidgets(
      'when avoidance activates, it should preserve child state',
      (tester) async {
        var initializations = 0;
        await tester.pumpWidget(
          _testView(
            child: MaybeSafeArea(
              child: _StatefulChild(onInit: () => initializations += 1),
            ),
          ),
        );
        await tester.pump();

        expect(initializations, 1);
      },
    );

    testWidgets(
      'when avoidance is painted on the first frame, it should hit test at the painted position',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          _testView(
            child: Stack(
              children: [
                Positioned(
                  left: 100,
                  child: MaybeSafeArea(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => taps += 1,
                      child: const SizedBox(width: 40, height: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.tapAt(const Offset(110, 50));

        expect(taps, 1);
      },
    );

    testWidgets(
      'when a retained ancestor transform crosses an unsafe edge, it should update without repainting the boundary',
      (tester) async {
        const childKey = ValueKey('child');
        late StateSetter rebuild;
        var offset = const Offset(0, 200);
        var paints = 0;
        final painter = _CountingPainter(onPaint: () => paints += 1);
        await tester.pumpWidget(
          _testView(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return Align(
                  alignment: Alignment.topLeft,
                  child: Transform.translate(
                    offset: offset,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: painter,
                        child: const MaybeSafeArea(
                          left: false,
                          right: false,
                          bottom: false,
                          child: SizedBox(key: childKey, width: 40, height: 20),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        await tester.pump();
        rebuild(() => offset = Offset.zero);
        await tester.pump();
        final crossingPosition = tester.getTopLeft(find.byKey(childKey));
        await tester.pump();

        expect(
          (
            crossingPosition,
            tester.getTopLeft(find.byKey(childKey)),
            paints,
          ),
          (const Offset(0, 40), const Offset(0, 40), 1),
        );
      },
    );

    testWidgets(
      'when a scrolling child crosses an unsafe edge, it should avoid it in the same frame',
      (tester) async {
        _useTestView(tester);
        const childKey = ValueKey('child');
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _testApp(
            child: ListView(
              controller: controller,
              padding: EdgeInsets.zero,
              children: const [
                SizedBox(height: 200),
                MaybeSafeArea(
                  left: false,
                  right: false,
                  bottom: false,
                  child: SizedBox(key: childKey, height: 20),
                ),
                SizedBox(height: 600),
              ],
            ),
          ),
        );
        await tester.pump();
        controller.jumpTo(200);
        await tester.pump();
        final crossingPosition = tester.getTopLeft(find.byKey(childKey));
        await tester.pump();

        expect(
          (crossingPosition, tester.getTopLeft(find.byKey(childKey))),
          (const Offset(0, 40), const Offset(0, 40)),
        );
      },
    );

    testWidgets(
      'when a scrolling child leaves the view, it should progressively clip at the safe edge',
      (tester) async {
        _useTestView(tester);
        const boundaryKey = ValueKey('boundary');
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _testApp(
            child: RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: const Color(0xFF0000FF),
                child: ListView(
                  controller: controller,
                  padding: EdgeInsets.zero,
                  children: const [
                    SizedBox(height: 200),
                    MaybeSafeArea(
                      left: false,
                      right: false,
                      bottom: false,
                      child: ColoredBox(
                        color: Color(0xFFFF0000),
                        child: SizedBox(height: 20),
                      ),
                    ),
                    SizedBox(height: 600),
                  ],
                ),
              ),
            ),
          ),
        );

        Future<(int, int)> pixelsAt(int firstY, int secondY) async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(boundaryKey),
          );
          return (await tester.runAsync(() async {
            final image = await boundary.toImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              final firstPixel = firstY * image.width * 4 + 100 * 4;
              final secondPixel = secondY * image.width * 4 + 100 * 4;
              return (
                bytes!.getUint32(firstPixel),
                bytes.getUint32(secondPixel),
              );
            } finally {
              image.dispose();
            }
          }))!;
        }

        controller.jumpTo(200);
        await tester.pump();
        final fullyVisiblePixels = await pixelsAt(45, 55);
        controller.jumpTo(210);
        await tester.pump();
        final partlyVisiblePixels = await pixelsAt(45, 55);
        controller.jumpTo(219);
        await tester.pump();
        final lastPixel = await pixelsAt(40, 41);
        controller.jumpTo(220);
        await tester.pump();
        final fullyClippedPixels = await pixelsAt(40, 41);

        expect(
          (
            fullyVisiblePixels,
            partlyVisiblePixels,
            lastPixel,
            fullyClippedPixels,
          ),
          (
            (0xFF0000FF, 0xFF0000FF),
            (0xFF0000FF, 0x0000FFFF),
            (0xFF0000FF, 0x0000FFFF),
            (0x0000FFFF, 0x0000FFFF),
          ),
        );
      },
    );

    testWidgets(
      'when an oversized scrolling child leaves the view, it should progressively clip at the safe edge',
      (tester) async {
        _useTestView(tester);
        const boundaryKey = ValueKey('oversized-boundary');
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _testApp(
            child: RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: const Color(0xFF0000FF),
                child: ListView(
                  controller: controller,
                  padding: EdgeInsets.zero,
                  children: const [
                    SizedBox(height: 200),
                    MaybeSafeArea(
                      left: false,
                      right: false,
                      bottom: false,
                      child: ColoredBox(
                        color: Color(0xFFFF0000),
                        child: SizedBox(height: 560),
                      ),
                    ),
                    SizedBox(height: 600),
                  ],
                ),
              ),
            ),
          ),
        );

        Future<(int?, int?, int)> redExtent() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(boundaryKey),
          );
          return (await tester.runAsync(() async {
            final image = await boundary.toImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              int? first;
              int? last;
              var count = 0;
              for (var y = 0; y < image.height; y += 1) {
                final pixel = y * image.width * 4 + 100 * 4;
                if (bytes!.getUint32(pixel) != 0xFF0000FF) continue;
                first ??= y;
                last = y;
                count += 1;
              }
              return (first, last, count);
            } finally {
              image.dispose();
            }
          }))!;
        }

        final extents = <(int?, int?, int)>[];
        for (final offset in [220.0, 500.0, 759.0, 760.0]) {
          controller.jumpTo(offset);
          await tester.pump();
          extents.add(await redExtent());
        }

        expect(
          extents,
          const <(int?, int?, int)>[
            (40, 579, 540),
            (40, 299, 260),
            (40, 40, 1),
            (null, null, 0),
          ],
        );
      },
    );

    testWidgets(
      'when a same-screen Morph moves and expands it, it should remain continuous and avoid unsafe edges in flight',
      (tester) async {
        _useTestView(tester);
        const sourceKey = ValueKey('same-screen-morph-source');
        const destinationKey = ValueKey('same-screen-morph-destination');
        late StateSetter rebuild;
        var expanded = false;
        await tester.pumpWidget(
          _testApp(
            child: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return Stack(
                    children: [
                      Positioned(
                        left: expanded ? 80 : 100,
                        width: 100,
                        height: expanded ? 600 : 520,
                        child: Morph(
                          tag: 'same-screen-maybe-safe-area',
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.linear,
                          child: MaybeSafeArea(
                            left: false,
                            right: false,
                            child: ColoredBox(
                              key: expanded ? destinationKey : sourceKey,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final sourceRect = tester.getRect(find.byKey(sourceKey));

        rebuild(() => expanded = true);
        await tester.pump();
        await tester.pump();
        final firstFlightRect = tester.getRect(
          find.descendant(
            of: _morphOverlay(),
            matching: find.byKey(sourceKey),
          ),
        );
        await tester.pump(const Duration(milliseconds: 99));
        final beforeOversizeRect = tester.getRect(
          find.descendant(
            of: _morphOverlay(),
            matching: find.byKey(sourceKey),
          ),
        );
        await tester.pump(const Duration(milliseconds: 2));
        final afterOversizeRect = tester.getRect(
          find.descendant(
            of: _morphOverlay(),
            matching: find.byKey(sourceKey),
          ),
        );
        await tester.pump(const Duration(milliseconds: 99));
        final midpointFlightRect = tester.getRect(
          find.descendant(
            of: _morphOverlay(),
            matching: find.byKey(destinationKey),
          ),
        );
        await tester.pumpAndSettle();
        final destinationRect = tester.getRect(find.byKey(destinationKey));

        expect(
          [
            sourceRect,
            firstFlightRect,
            beforeOversizeRect,
            afterOversizeRect,
            midpointFlightRect,
            destinationRect,
          ],
          [
            rectMoreOrLessEquals(const Rect.fromLTWH(100, 40, 100, 520)),
            rectMoreOrLessEquals(const Rect.fromLTWH(100, 40, 100, 520)),
            rectMoreOrLessEquals(const Rect.fromLTWH(95.05, 40, 100, 539.8)),
            rectMoreOrLessEquals(const Rect.fromLTWH(94.95, 39.8, 100, 540.2)),
            rectMoreOrLessEquals(const Rect.fromLTWH(90, 20, 100, 560)),
            rectMoreOrLessEquals(const Rect.fromLTWH(80, 0, 100, 600)),
          ],
        );
      },
    );

    testWidgets(
      'when a route Morph moves and expands it, it should remain continuous and avoid unsafe edges in flight',
      (tester) async {
        _useTestView(tester);
        const sourceKey = ValueKey('route-morph-source');
        const destinationKey = ValueKey('route-morph-destination');
        await tester.pumpWidget(
          _testApp(
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: Stack(
                    children: [
                      const Positioned(
                        left: 20,
                        top: 60,
                        width: 40,
                        height: 20,
                        child: Morph(
                          tag: 'route-maybe-safe-area',
                          curve: Curves.linear,
                          child: MaybeSafeArea(
                            child: ColoredBox(
                              key: sourceKey,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 100,
                        bottom: 80,
                        child: FilledButton(
                          key: const ValueKey('push-maybe-safe-area-route'),
                          onPressed: () async {
                            await Navigator.of(context).push<void>(
                              PageRouteBuilder<void>(
                                opaque: false,
                                transitionDuration: const Duration(milliseconds: 400),
                                pageBuilder: (context, animation, secondaryAnimation) {
                                  return const Material(
                                    type: MaterialType.transparency,
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          width: 160,
                                          height: 100,
                                          child: Morph(
                                            tag: 'route-maybe-safe-area',
                                            curve: Curves.linear,
                                            child: MaybeSafeArea(
                                              child: ColoredBox(
                                                key: destinationKey,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
                              ),
                            );
                          },
                          child: const Text('Push'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final sourceRect = tester.getRect(find.byKey(sourceKey));

        await tester.tap(find.byKey(const ValueKey('push-maybe-safe-area-route')));
        await tester.pump();
        await tester.pump();
        final firstFlightRect = tester.getRect(
          find.descendant(
            of: _morphOverlay(),
            matching: find.byKey(sourceKey),
          ),
        );
        await tester.pump(const Duration(milliseconds: 200));
        final midpointFlightRect = tester.getRect(
          find.descendant(
            of: _morphOverlay(),
            matching: find.byKey(destinationKey),
          ),
        );
        await tester.pumpAndSettle();
        final destinationRect = tester.getRect(find.byKey(destinationKey));

        expect(
          [
            sourceRect,
            firstFlightRect,
            midpointFlightRect,
            destinationRect,
          ],
          const [
            Rect.fromLTWH(20, 60, 40, 20),
            Rect.fromLTWH(20, 60, 40, 20),
            Rect.fromLTWH(12, 40, 100, 60),
            Rect.fromLTWH(12, 40, 160, 100),
          ],
        );
      },
    );

    testWidgets(
      'when a route Morph is inside it, it should include each correction throughout push and pop flights',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const sourceKey = ValueKey('ancestor-route-morph-source');
        const destinationKey = ValueKey('ancestor-route-morph-destination');
        const pushKey = ValueKey('push-ancestor-maybe-safe-area-route');
        const padding = EdgeInsets.only(top: 47, bottom: 34);
        await tester.pumpWidget(
          _testApp(
            padding: padding,
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: Stack(
                    children: [
                      const Positioned(
                        left: 20,
                        top: 79.52,
                        child: MaybeSafeArea(
                          left: false,
                          right: false,
                          bottom: false,
                          child: Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Morph(
                              tag: 'ancestor-route-maybe-safe-area',
                              curve: Curves.easeOutCubic,
                              child: SizedBox.square(
                                key: sourceKey,
                                dimension: 50,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 100,
                        bottom: 80,
                        child: FilledButton(
                          key: pushKey,
                          onPressed: () async {
                            await Navigator.of(context).push<void>(
                              PageRouteBuilder<void>(
                                opaque: true,
                                transitionDuration: const Duration(
                                  milliseconds: 300,
                                ),
                                pageBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                    ) {
                                      return const Material(
                                        child: Stack(
                                          children: [
                                            Positioned(
                                              left: 20,
                                              child: MaybeSafeArea(
                                                left: false,
                                                right: false,
                                                bottom: false,
                                                child: Padding(
                                                  padding: EdgeInsets.only(top: 12),
                                                  child: Morph(
                                                    tag: 'ancestor-route-maybe-safe-area',
                                                    curve: Curves.easeOutCubic,
                                                    child: SizedBox.square(
                                                      key: destinationKey,
                                                      dimension: 50,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                transitionsBuilder:
                                    (
                                      context,
                                      animation,
                                      secondaryAnimation,
                                      child,
                                    ) => child,
                              ),
                            );
                          },
                          child: const Text('Push'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        final sourceRect = tester.getRect(find.byKey(sourceKey));
        final sourcePadding = MediaQuery.paddingOf(
          tester.element(find.byKey(sourceKey)),
        );

        await tester.tap(find.byKey(pushKey));
        await tester.pump();
        final destinationAfterFirstPumpRect = tester.getRect(
          find.byKey(destinationKey, skipOffstage: false),
        );
        await tester.pump();
        final flightFinder = find.descendant(
          of: _morphOverlay(),
          matching: find.byWidgetPredicate(
            (widget) => widget.key == sourceKey || widget.key == destinationKey,
          ),
        );
        final firstFlightRect = tester.getRect(flightFinder);
        final destinationDuringFlightRect = tester.getRect(
          find.byKey(destinationKey),
        );
        final destinationPadding = MediaQuery.paddingOf(
          tester.element(find.byKey(destinationKey)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final oneThirdFlightTop = tester.getTopLeft(flightFinder).dy;
        await tester.pump(const Duration(milliseconds: 199));
        final lastFlightRect = tester.getRect(flightFinder);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        final destinationRect = tester.getRect(find.byKey(destinationKey));
        Navigator.of(tester.element(find.byKey(destinationKey))).pop();
        await tester.pump();
        await tester.pump();
        final firstReturnFlightRect = tester.getRect(flightFinder);
        await tester.pump(const Duration(milliseconds: 100));
        final oneThirdReturnFlightTop = tester.getTopLeft(flightFinder).dy;
        await tester.pump(const Duration(milliseconds: 199));
        final lastReturnFlightRect = tester.getRect(flightFinder);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpAndSettle();
        final returnedSourceRect = tester.getRect(find.byKey(sourceKey));

        expect(
          [
            sourcePadding,
            sourceRect,
            firstFlightRect,
            destinationPadding,
            destinationAfterFirstPumpRect,
            destinationDuringFlightRect,
            oneThirdFlightTop,
            lastFlightRect,
            destinationRect,
            firstReturnFlightRect,
            oneThirdReturnFlightTop,
            lastReturnFlightRect,
            returnedSourceRect,
          ],
          [
            padding,
            rectMoreOrLessEquals(
              const Rect.fromLTWH(20, 91.52, 50, 50),
            ),
            rectMoreOrLessEquals(
              const Rect.fromLTWH(20, 91.52, 50, 50),
            ),
            padding,
            rectMoreOrLessEquals(const Rect.fromLTWH(20, 59, 50, 50)),
            rectMoreOrLessEquals(const Rect.fromLTWH(20, 59, 50, 50)),
            inInclusiveRange(59.0, 91.52),
            rectMoreOrLessEquals(
              const Rect.fromLTWH(20, 59.0000012044, 50, 50),
              epsilon: 0.001,
            ),
            rectMoreOrLessEquals(const Rect.fromLTWH(20, 59, 50, 50)),
            rectMoreOrLessEquals(const Rect.fromLTWH(20, 59, 50, 50)),
            inInclusiveRange(59.0, 91.52),
            rectMoreOrLessEquals(
              const Rect.fromLTWH(20, 91.5199987956, 50, 50),
              epsilon: 0.001,
            ),
            rectMoreOrLessEquals(
              const Rect.fromLTWH(20, 91.52, 50, 50),
            ),
          ],
        );
      },
    );

    testWidgets(
      'when no enabled edge has unsafe padding, it should not require compositing',
      (tester) async {
        await tester.pumpWidget(
          _testView(
            padding: EdgeInsets.zero,
            child: const MaybeSafeArea(child: SizedBox(width: 40, height: 20)),
          ),
        );

        expect(
          tester.renderObject(find.byType(MaybeSafeArea)).needsCompositing,
          isFalse,
        );
      },
    );

    testWidgets(
      'when every unsafe edge is disabled, it should not require compositing',
      (tester) async {
        await tester.pumpWidget(
          _testView(
            child: const MaybeSafeArea(
              left: false,
              top: false,
              right: false,
              bottom: false,
              child: SizedBox(width: 40, height: 20),
            ),
          ),
        );

        expect(
          tester.renderObject(find.byType(MaybeSafeArea)).needsCompositing,
          isFalse,
        );
      },
    );

    testWidgets(
      'when enabled padding toggles, it should update compositing in the changed frame',
      (tester) async {
        late StateSetter rebuild;
        var padding = EdgeInsets.zero;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return _testView(
                padding: padding,
                child: const MaybeSafeArea(
                  child: SizedBox(width: 40, height: 20),
                ),
              );
            },
          ),
        );
        final renderObject = tester.renderObject(
          find.byType(MaybeSafeArea),
        );
        final initiallyComposited = renderObject.needsCompositing;
        rebuild(() => padding = _viewPadding);
        await tester.pump();
        final activelyComposited = renderObject.needsCompositing;
        rebuild(() => padding = EdgeInsets.zero);
        await tester.pump();

        expect(
          (
            initiallyComposited,
            activelyComposited,
            renderObject.needsCompositing,
          ),
          (false, true, false),
        );
      },
    );

    testWidgets(
      'when geometry is painted, it should not schedule correction frames',
      (tester) async {
        await tester.pumpWidget(
          _testView(
            child: const MaybeSafeArea(child: SizedBox(width: 40, height: 20)),
          ),
        );
        final scheduledAfterFirstFrame = tester.binding.hasScheduledFrame;
        await tester.pump();

        expect(
          (scheduledAfterFirstFrame, tester.binding.hasScheduledFrame),
          (false, false),
        );
      },
    );
  });
}

class _StatefulChild extends StatefulWidget {
  const _StatefulChild({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_StatefulChild> createState() => _StatefulChildState();
}

class _StatefulChildState extends State<_StatefulChild> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 40, height: 20);
}

class _CountingPainter extends CustomPainter {
  const _CountingPainter({required this.onPaint});

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) => onPaint();

  @override
  bool shouldRepaint(covariant _CountingPainter oldDelegate) => false;
}
