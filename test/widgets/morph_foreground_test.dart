import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

Future<Color> _pixelColor(
  WidgetTester tester, {
  required Key boundaryKey,
  required Offset position,
}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final x = position.dx.round();
      final y = position.dy.round();
      final offset = (y * image.width + x) * 4;
      return Color.fromARGB(
        bytes!.getUint8(offset + 3),
        bytes.getUint8(offset),
        bytes.getUint8(offset + 1),
        bytes.getUint8(offset + 2),
      );
    } finally {
      image.dispose();
    }
  }))!;
}

RenderObject _foregroundBoundary(
  WidgetTester tester, {
  required Key childKey,
}) {
  RenderObject? renderObject = tester.renderObject(find.byKey(childKey));
  while (renderObject != null && renderObject.runtimeType.toString() != '_RenderMorphForegroundBoundary') {
    renderObject = renderObject.parent;
  }
  if (renderObject == null) {
    throw StateError('The MorphForeground render boundary was not found.');
  }
  return renderObject;
}

int _activeSemanticsLabelCount(
  WidgetTester tester, {
  required String label,
}) {
  final renderView = tester.binding.renderViews.firstWhere(
    (view) => view.flutterView.viewId == tester.view.viewId,
  );
  final root = renderView.owner?.semanticsOwner?.rootSemanticsNode;
  if (root == null) return 0;
  var count = 0;
  void visit(SemanticsNode node) {
    if (node.label == label) count += 1;
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return count;
}

final class _PaintCounter {
  int count = 0;
}

final class _CountingPainter extends CustomPainter {
  _CountingPainter(this.counter);

  final _PaintCounter counter;

  @override
  void paint(Canvas canvas, Size size) {
    counter.count += 1;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(covariant _CountingPainter oldDelegate) => false;
}

final class _AnimationColorPainter extends CustomPainter {
  _AnimationColorPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = animation.value < 0.5 ? Colors.red : Colors.green,
    );
  }

  @override
  bool shouldRepaint(covariant _AnimationColorPainter oldDelegate) => false;
}

class _RouteForegroundApp extends StatelessWidget {
  const _RouteForegroundApp();

  Widget _buildSourceForeground() {
    return const Positioned(
      left: 150,
      top: 100,
      child: MorphForeground(
        child: ColoredBox(
          color: Colors.red,
          child: SizedBox(width: 100, height: 50),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Stack(
              children: [
                Morph(
                  tag: 'route-surface',
                  child: Container(color: Colors.grey),
                ),
                _buildSourceForeground(),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FilledButton(
                    key: const ValueKey('push'),
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        PageRouteBuilder<void>(
                          transitionDuration: const Duration(
                            milliseconds: 400,
                          ),
                          reverseTransitionDuration: const Duration(
                            milliseconds: 400,
                          ),
                          pageBuilder: (context, animation, secondaryAnimation) {
                            return Scaffold(
                              body: Stack(
                                children: [
                                  Morph(
                                    tag: 'route-surface',
                                    child: Container(color: Colors.blue),
                                  ),
                                  const Positioned(
                                    left: 150,
                                    top: 100,
                                    child: MorphForeground(
                                      child: ColoredBox(
                                        color: Colors.green,
                                        child: SizedBox(
                                          width: 100,
                                          height: 50,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          transitionsBuilder: (
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
    );
  }
}

void main() {
  group('MorphForeground', () {
    testWidgets(
      'when a Morph flight covers a sibling, it should paint the foreground above the flight',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('boundary');
        var expanded = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: [
                        Morph(
                          tag: 'surface',
                          duration: const Duration(milliseconds: 400),
                          child: Container(
                            key: ValueKey(expanded),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                            color: Colors.blue,
                          ),
                        ),
                        const Positioned(
                          left: 150,
                          top: 100,
                          child: MorphForeground(
                            child: ColoredBox(
                              color: Colors.red,
                              child: SizedBox(width: 100, height: 50),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          await _pixelColor(
            tester,
            boundaryKey: boundaryKey,
            position: const Offset(200, 125),
          ),
          const Color(0xFFF44336),
        );
      },
    );

    testWidgets(
      'when a foreground paints outside its bounds, it should preserve the overflow during the flight',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('shadow-boundary');
        var expanded = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: [
                        Morph(
                          tag: 'shadow-surface',
                          duration: const Duration(milliseconds: 400),
                          child: Container(
                            key: ValueKey(expanded),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                            color: Colors.blue,
                          ),
                        ),
                        const Positioned(
                          left: 150,
                          top: 100,
                          child: MorphForeground(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.green,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                              child: SizedBox(width: 100, height: 50),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          await _pixelColor(
            tester,
            boundaryKey: boundaryKey,
            position: const Offset(145, 125),
          ),
          const Color(0xFFF44336),
        );
      },
    );

    testWidgets(
      'when multiple foregrounds overlap, it should preserve their paint order during the flight',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('multiple-boundary');
        var expanded = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: <Widget>[
                        Morph(
                          tag: 'multiple-surface',
                          duration: const Duration(milliseconds: 400),
                          child: SizedBox(
                            key: ValueKey<bool>(expanded),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                            child: const ColoredBox(color: Colors.blue),
                          ),
                        ),
                        const Positioned(
                          left: 100,
                          top: 100,
                          child: MorphForeground(
                            child: ColoredBox(
                              color: Colors.red,
                              child: SizedBox(width: 100, height: 50),
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 150,
                          top: 100,
                          child: MorphForeground(
                            child: ColoredBox(
                              color: Colors.green,
                              child: SizedBox(width: 100, height: 50),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          (
            await _pixelColor(
              tester,
              boundaryKey: boundaryKey,
              position: const Offset(125, 125),
            ),
            await _pixelColor(
              tester,
              boundaryKey: boundaryKey,
              position: const Offset(175, 125),
            ),
          ),
          (const Color(0xFFF44336), const Color(0xFF4CAF50)),
        );
      },
    );

    testWidgets(
      'when foreground content changes during a flight, it should paint the current visual state',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('live-boundary');
        var expanded = false;
        var foregroundColor = Colors.red;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: [
                        Morph(
                          tag: 'live-surface',
                          duration: const Duration(milliseconds: 400),
                          child: Container(
                            key: ValueKey(expanded),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                            color: Colors.blue,
                          ),
                        ),
                        Positioned(
                          left: 150,
                          top: 100,
                          child: MorphForeground(
                            child: ColoredBox(
                              color: foregroundColor,
                              child: const SizedBox(width: 100, height: 50),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        update(() => foregroundColor = Colors.green);
        await tester.pump();

        expect(
          await _pixelColor(
            tester,
            boundaryKey: boundaryKey,
            position: const Offset(200, 125),
          ),
          const Color(0xFF4CAF50),
        );
      },
    );

    testWidgets(
      'when foreground paint animates during a flight, it should paint the current visual state',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('animated-paint-boundary');
        final paintAnimation = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 200),
        );
        addTearDown(paintAnimation.dispose);
        var expanded = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: <Widget>[
                        Morph(
                          tag: 'animated-paint-surface',
                          duration: const Duration(milliseconds: 800),
                          child: SizedBox(
                            key: ValueKey<bool>(expanded),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                            child: const ColoredBox(color: Colors.blue),
                          ),
                        ),
                        Positioned(
                          left: 150,
                          top: 100,
                          child: MorphForeground(
                            child: CustomPaint(
                              painter: _AnimationColorPainter(paintAnimation),
                              size: const Size(100, 50),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        paintAnimation.forward();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        paintAnimation.stop();

        expect(
          await _pixelColor(
            tester,
            boundaryKey: boundaryKey,
            position: const Offset(200, 125),
          ),
          const Color(0xFF4CAF50),
        );
      },
    );

    testWidgets(
      'when foreground paint changes during a flight, it should not rebuild the Morph overlay',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('paint-only-boundary');
        final foregroundColor = ValueNotifier<Color>(Colors.red);
        addTearDown(foregroundColor.dispose);
        var expanded = false;
        late StateSetter update;
        var overlayRebuilds = 0;
        final previousRebuildCallback = debugOnRebuildDirtyWidget;
        addTearDown(() {
          debugOnRebuildDirtyWidget = previousRebuildCallback;
        });
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: <Widget>[
                        Morph(
                          tag: 'overlay-rebuild-surface',
                          duration: const Duration(milliseconds: 400),
                          child: SizedBox(
                            key: ValueKey<bool>(expanded),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                          ),
                        ),
                        Positioned(
                          left: 150,
                          top: 100,
                          child: MorphForeground(
                            child: ValueListenableBuilder<Color>(
                              valueListenable: foregroundColor,
                              builder: (context, color, child) {
                                return ColoredBox(color: color, child: child);
                              },
                              child: const SizedBox(width: 100, height: 50),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        final morphOverlay = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_MorphOverlay',
        );
        final overlayBuilderElement = tester.element(
          find.descendant(
            of: morphOverlay,
            matching: find.byType(AnimatedBuilder),
          ),
        );
        debugOnRebuildDirtyWidget = (element, builtOnce) {
          previousRebuildCallback?.call(element, builtOnce);
          if (identical(element, overlayBuilderElement)) overlayRebuilds += 1;
        };
        overlayRebuilds = 0;

        foregroundColor.value = Colors.green;
        await tester.pump();
        await tester.pump();

        expect(
          (
            overlayRebuilds,
            await _pixelColor(
              tester,
              boundaryKey: boundaryKey,
              position: const Offset(200, 125),
            ),
          ),
          (0, const Color(0xFF4CAF50)),
        );
      },
    );

    testWidgets(
      'when an ancestor transform animates during a flight, it should paint the foreground at its current position',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('animated-transform-boundary');
        const foregroundKey = ValueKey('animated-transform-foreground');
        final transform = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 400),
        );
        addTearDown(transform.dispose);
        var expanded = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: <Widget>[
                        Morph(
                          tag: 'animated-transform-surface',
                          duration: const Duration(milliseconds: 600),
                          child: SizedBox(
                            key: ValueKey<bool>(expanded),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                            child: const ColoredBox(color: Colors.blue),
                          ),
                        ),
                        Positioned(
                          left: 50,
                          top: 80,
                          child: AnimatedBuilder(
                            animation: transform,
                            child: const MorphForeground(
                              child: ColoredBox(
                                key: foregroundKey,
                                color: Colors.red,
                                child: SizedBox(width: 60, height: 40),
                              ),
                            ),
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(
                                  160 * transform.value,
                                  40 * transform.value,
                                ),
                                child: child,
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        update(() => expanded = true);
        transform.forward();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final foreground = tester.renderObject<RenderBox>(
          find.byKey(foregroundKey),
        );
        final currentCenter = foreground.localToGlobal(
          foreground.size.center(Offset.zero),
        );
        final currentColor = await _pixelColor(
          tester,
          boundaryKey: boundaryKey,
          position: currentCenter,
        );
        transform.stop();

        expect(currentColor, const Color(0xFFF44336));
      },
    );

    testWidgets(
      'when source paint and an ancestor transform change on the same flight tick, it should paint the current state at its current position',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('dirty-transform-boundary');
        const foregroundKey = ValueKey('dirty-transform-foreground');
        final transform = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 400),
        );
        final foregroundColor = ValueNotifier<Color>(Colors.red);
        addTearDown(transform.dispose);
        addTearDown(foregroundColor.dispose);
        var expanded = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: <Widget>[
                        Morph(
                          tag: 'dirty-transform-surface',
                          duration: const Duration(milliseconds: 600),
                          child: SizedBox(
                            key: ValueKey<bool>(expanded),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                            child: const ColoredBox(color: Colors.blue),
                          ),
                        ),
                        Positioned(
                          left: 50,
                          top: 80,
                          child: AnimatedBuilder(
                            animation: transform,
                            child: MorphForeground(
                              child: ValueListenableBuilder<Color>(
                                valueListenable: foregroundColor,
                                builder: (context, color, child) {
                                  return ColoredBox(
                                    color: color,
                                    child: child,
                                  );
                                },
                                child: const SizedBox(
                                  key: foregroundKey,
                                  width: 60,
                                  height: 40,
                                ),
                              ),
                            ),
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(160 * transform.value, 0),
                                child: child,
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        foregroundColor.value = Colors.green;
        transform.value = 0.75;
        await tester.pump(const Duration(milliseconds: 16));
        final foreground = tester.renderObject<RenderBox>(
          find.byKey(foregroundKey),
        );

        expect(
          await _pixelColor(
            tester,
            boundaryKey: boundaryKey,
            position: foreground.localToGlobal(
              foreground.size.center(Offset.zero),
            ),
          ),
          const Color(0xFF4CAF50),
        );
      },
    );

    testWidgets(
      'when an ancestor scales and rotates during a flight, it should preserve the foreground placement',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('scaled-rotated-boundary');
        const foregroundKey = ValueKey('scaled-rotated-foreground');
        var expanded = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: <Widget>[
                        Morph(
                          tag: 'scaled-rotated-surface',
                          duration: const Duration(milliseconds: 400),
                          child: SizedBox(
                            key: ValueKey<bool>(expanded),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                            child: const ColoredBox(color: Colors.blue),
                          ),
                        ),
                        Positioned(
                          left: 200,
                          top: 80,
                          child: Transform.rotate(
                            angle: math.pi / 2,
                            alignment: Alignment.topLeft,
                            child: Transform.scale(
                              scale: 1.5,
                              alignment: Alignment.topLeft,
                              child: const MorphForeground(
                                child: SizedBox(
                                  key: foregroundKey,
                                  width: 60,
                                  height: 30,
                                  child: Row(
                                    children: <Widget>[
                                      SizedBox(
                                        width: 30,
                                        height: 30,
                                        child: ColoredBox(color: Colors.red),
                                      ),
                                      SizedBox(
                                        width: 30,
                                        height: 30,
                                        child: ColoredBox(color: Colors.green),
                                      ),
                                    ],
                                  ),
                                ),
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
          ),
        );
        await tester.pumpAndSettle();

        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        final foreground = tester.renderObject<RenderBox>(
          find.byKey(foregroundKey),
        );
        final redPosition = foreground.localToGlobal(const Offset(15, 15));
        final greenPosition = foreground.localToGlobal(const Offset(45, 15));

        expect(
          (
            await _pixelColor(
              tester,
              boundaryKey: boundaryKey,
              position: redPosition,
            ),
            await _pixelColor(
              tester,
              boundaryKey: boundaryKey,
              position: greenPosition,
            ),
          ),
          (const Color(0xFFF44336), const Color(0xFF4CAF50)),
        );
      },
    );

    testWidgets(
      'when a static foreground is projected, it should not repaint on every flight tick',
      (tester) async {
        final paintCounter = _PaintCounter();
        var expanded = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: <Widget>[
                      Morph(
                        tag: 'static-paint-surface',
                        duration: const Duration(milliseconds: 400),
                        child: SizedBox(
                          key: ValueKey<bool>(expanded),
                          width: expanded ? 400 : 40,
                          height: expanded ? 300 : 40,
                        ),
                      ),
                      Positioned(
                        left: 150,
                        top: 100,
                        child: MorphForeground(
                          child: CustomPaint(
                            painter: _CountingPainter(paintCounter),
                            size: const Size(100, 50),
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

        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        final countAfterProjection = paintCounter.count;
        for (var index = 0; index < 8; index += 1) {
          await tester.pump(const Duration(milliseconds: 16));
        }

        expect(paintCounter.count, countAfterProjection);
      },
    );

    testWidgets(
      'when shared and distinct flight animations overlap, it should remain projected until the last flight ends',
      (tester) async {
        const foregroundKey = ValueKey('overlapping-flight-foreground');
        var expanded = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: <Widget>[
                      for (var index = 0; index < 3; index += 1)
                        Morph(
                          tag: 'overlapping-flight-$index',
                          duration: Duration(
                            milliseconds: index < 2 ? 180 : 600,
                          ),
                          child: SizedBox(
                            key: ValueKey<(int, bool)>((index, expanded)),
                            width: expanded ? 300 : 40,
                            height: expanded ? 200 : 40,
                          ),
                        ),
                      const Positioned(
                        left: 150,
                        top: 100,
                        child: MorphForeground(
                          child: SizedBox(
                            key: foregroundKey,
                            width: 100,
                            height: 50,
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

        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        final boundary = _foregroundBoundary(
          tester,
          childKey: foregroundKey,
        );
        final afterShortFlights = boundary.isRepaintBoundary;
        await tester.pumpAndSettle();

        expect(
          (afterShortFlights, boundary.isRepaintBoundary),
          (true, false),
        );
      },
    );

    testWidgets(
      'when a flight finishes, it should disable the foreground repaint boundary again',
      (tester) async {
        const foregroundKey = ValueKey('conditional-boundary-foreground');
        var expanded = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: <Widget>[
                      Morph(
                        tag: 'conditional-boundary-surface',
                        duration: const Duration(milliseconds: 400),
                        child: SizedBox(
                          key: ValueKey<bool>(expanded),
                          width: expanded ? 400 : 40,
                          height: expanded ? 300 : 40,
                        ),
                      ),
                      const Positioned(
                        left: 150,
                        top: 100,
                        child: MorphForeground(
                          child: SizedBox(
                            key: foregroundKey,
                            width: 100,
                            height: 50,
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

        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        final boundary = _foregroundBoundary(
          tester,
          childKey: foregroundKey,
        );
        final duringFlight = boundary.isRepaintBoundary;
        await tester.pumpAndSettle();

        expect((duringFlight, boundary.isRepaintBoundary), (true, false));
      },
    );

    testWidgets(
      'when a foreground is projected, it should retain the source offset layer across flight ticks',
      (tester) async {
        const foregroundKey = ValueKey('transform-layer-foreground');
        var expanded = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: <Widget>[
                      Morph(
                        tag: 'transform-layer-surface',
                        duration: const Duration(milliseconds: 400),
                        child: SizedBox(
                          key: ValueKey<bool>(expanded),
                          width: expanded ? 400 : 40,
                          height: expanded ? 300 : 40,
                        ),
                      ),
                      const Positioned(
                        left: 150,
                        top: 100,
                        child: MorphForeground(
                          child: SizedBox(
                            key: foregroundKey,
                            width: 100,
                            height: 50,
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

        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        final boundary = _foregroundBoundary(
          tester,
          childKey: foregroundKey,
        );
        final sourceLayer = boundary.debugLayer;
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 16));

        expect(
          (
            sourceLayer is OffsetLayer && sourceLayer is! TransformLayer,
            identical(boundary.debugLayer, sourceLayer),
          ),
          (true, true),
        );
      },
    );

    testWidgets(
      'when a foreground is projected, it should suppress interaction and semantics only during the flight',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        const foregroundKey = ValueKey('interactive-foreground');
        var expanded = false;
        var taps = 0;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: <Widget>[
                      Morph(
                        tag: 'interactive-surface',
                        duration: const Duration(milliseconds: 400),
                        child: SizedBox(
                          key: ValueKey<bool>(expanded),
                          width: expanded ? 400 : 40,
                          height: expanded ? 300 : 40,
                        ),
                      ),
                      Positioned(
                        left: 150,
                        top: 100,
                        child: MorphForeground(
                          child: Semantics(
                            label: 'Foreground action',
                            button: true,
                            child: GestureDetector(
                              excludeFromSemantics: true,
                              behavior: HitTestBehavior.opaque,
                              onTap: () => taps += 1,
                              child: const SizedBox(
                                key: foregroundKey,
                                width: 100,
                                height: 50,
                              ),
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

        update(() => expanded = true);
        await tester.pump();
        await tester.pump();
        await tester.pump();
        final projected = _foregroundBoundary(
          tester,
          childKey: foregroundKey,
        ).isRepaintBoundary;
        final semanticsDuring = _activeSemanticsLabelCount(
          tester,
          label: 'Foreground action',
        );
        await tester.tap(find.byKey(foregroundKey), warnIfMissed: false);
        await tester.pump();
        final tapsDuring = taps;

        await tester.pumpAndSettle();
        await tester.pump();
        final semanticsAfter = _activeSemanticsLabelCount(
          tester,
          label: 'Foreground action',
        );
        await tester.tap(find.byKey(foregroundKey), warnIfMissed: false);
        await tester.pump();
        semantics.dispose();

        expect(
          (
            projected,
            semanticsDuring,
            tapsDuring,
            semanticsAfter,
            taps,
          ),
          (true, 0, 0, 1, 1),
        );
      },
    );

    testWidgets(
      'when a projected foreground is removed, it should remove the live projection during the flight',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('removal-boundary');
        const foregroundKey = ValueKey('removable-foreground');
        var generation = 0;
        var showForeground = true;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: <Widget>[
                        Morph(
                          tag: 'removal-surface',
                          duration: const Duration(milliseconds: 400),
                          child: SizedBox(
                            key: ValueKey<int>(generation),
                            width: 400,
                            height: 300,
                            child: const ColoredBox(color: Colors.blue),
                          ),
                        ),
                        if (showForeground)
                          const Positioned(
                            left: 150,
                            top: 100,
                            child: MorphForeground(
                              child: ColoredBox(
                                key: foregroundKey,
                                color: Colors.red,
                                child: SizedBox(width: 100, height: 50),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        update(() => generation += 1);
        await tester.pump();
        await tester.pump();
        final wasProjected = _foregroundBoundary(
          tester,
          childKey: foregroundKey,
        ).isRepaintBoundary;
        update(() => showForeground = false);
        await tester.pump();
        await tester.pump();

        expect(
          (
            wasProjected,
            find.byKey(foregroundKey).evaluate().length,
            tester.takeException(),
            await _pixelColor(
              tester,
              boundaryKey: boundaryKey,
              position: const Offset(200, 125),
            ),
          ),
          (true, 0, null, const Color(0xFF2196F3)),
        );
      },
    );

    testWidgets(
      'when a route Morph enters, it should paint the destination foreground above the flight',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('route-boundary');
        await tester.pumpWidget(
          const RepaintBoundary(
            key: boundaryKey,
            child: _RouteForegroundApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('push')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          await _pixelColor(
            tester,
            boundaryKey: boundaryKey,
            position: const Offset(200, 125),
          ),
          const Color(0xFF4CAF50),
        );
      },
    );

    testWidgets(
      'when a route Morph returns, it should paint the revealed foreground above the flight',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('route-boundary');
        await tester.pumpWidget(
          const RepaintBoundary(
            key: boundaryKey,
            child: _RouteForegroundApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('push')));
        await tester.pumpAndSettle();

        Navigator.of(
          tester.element(find.byType(MorphForeground).last),
        ).pop();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          await _pixelColor(
            tester,
            boundaryKey: boundaryKey,
            position: const Offset(200, 125),
          ),
          const Color(0xFFF44336),
        );
      },
    );
  });
}
