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

RenderObject _siblingBoundary(
  WidgetTester tester, {
  required Key childKey,
}) {
  RenderObject? renderObject = tester.renderObject(find.byKey(childKey));
  while (renderObject != null && renderObject.runtimeType.toString() != '_RenderMorphSiblingBoundary') {
    renderObject = renderObject.parent;
  }
  if (renderObject == null) {
    throw StateError('The MorphSibling render boundary was not found.');
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

final class _OvershootCurve extends Curve {
  const _OvershootCurve();

  @override
  double transformInternal(double t) => t * 2;
}

class _RouteSiblingApp extends StatelessWidget {
  const _RouteSiblingApp({
    this.onSourceAnimation,
    this.onDestinationAnimation,
  });

  final ValueChanged<double>? onSourceAnimation;
  final ValueChanged<double>? onDestinationAnimation;

  Widget _buildSourceSibling() {
    return Positioned(
      left: 150,
      top: 100,
      child: MorphSibling(
        tag: 'route-surface',
        transitionBuilder: onSourceAnimation == null
            ? null
            : (child, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    onSourceAnimation!(animation.value);
                    return child!;
                  },
                  child: child,
                );
              },
        child: const ColoredBox(
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
                _buildSourceSibling(),
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
                                  Positioned(
                                    left: 150,
                                    top: 100,
                                    child: MorphSibling(
                                      tag: 'route-surface',
                                      transitionBuilder: onDestinationAnimation == null
                                          ? null
                                          : (child, animation) {
                                              return AnimatedBuilder(
                                                animation: animation,
                                                builder: (context, child) {
                                                  onDestinationAnimation!(animation.value);
                                                  return child!;
                                                },
                                                child: child,
                                              );
                                            },
                                      child: const ColoredBox(
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
  group('MorphSibling', () {
    testWidgets(
      'when a Morph flight covers a sibling, it should paint the sibling above the flight',
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
                          child: MorphSibling(
                            tag: 'surface',
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
      'when painting above Morph is disabled, it should keep the sibling in its natural paint order',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('natural-order-boundary');
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
                          tag: 'natural-order-surface',
                          duration: const Duration(milliseconds: 400),
                          child: SizedBox(
                            key: ValueKey(expanded),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                            child: const ColoredBox(color: Colors.blue),
                          ),
                        ),
                        const Positioned(
                          left: 150,
                          top: 100,
                          child: MorphSibling(
                            tag: 'natural-order-surface',
                            paintAboveMorph: false,
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
          const Color(0xFF2196F3),
        );
      },
    );

    testWidgets(
      'when a later differently tagged Morph flies, it should paint above the opted-in sibling',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('tagged-order-boundary');
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
                          tag: 'lower-surface',
                          duration: const Duration(milliseconds: 400),
                          child: SizedBox(
                            key: ValueKey(('lower', expanded)),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                            child: const ColoredBox(color: Colors.blue),
                          ),
                        ),
                        const Positioned(
                          left: 150,
                          top: 100,
                          child: MorphSibling(
                            tag: 'lower-surface',
                            child: ColoredBox(
                              color: Colors.red,
                              child: SizedBox(width: 100, height: 50),
                            ),
                          ),
                        ),
                        Morph(
                          tag: 'upper-surface',
                          duration: const Duration(milliseconds: 400),
                          child: SizedBox(
                            key: ValueKey(('upper', expanded)),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                            child: const ColoredBox(color: Colors.green),
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
          const Color(0xFF4CAF50),
        );
      },
    );

    testWidgets(
      'when a sibling paints outside its bounds, it should preserve the overflow during the flight',
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
                          child: MorphSibling(
                            tag: 'shadow-surface',
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
      'when multiple siblings overlap, it should preserve their paint order during the flight',
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
                          child: MorphSibling(
                            tag: 'multiple-surface',
                            child: ColoredBox(
                              color: Colors.red,
                              child: SizedBox(width: 100, height: 50),
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 150,
                          top: 100,
                          child: MorphSibling(
                            tag: 'multiple-surface',
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
      'when sibling content changes during a flight, it should paint the current visual state',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('live-boundary');
        var expanded = false;
        var siblingColor = Colors.red;
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
                          child: MorphSibling(
                            tag: 'live-surface',
                            child: ColoredBox(
                              color: siblingColor,
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
        update(() => siblingColor = Colors.green);
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
      'when sibling paint animates during a flight, it should paint the current visual state',
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
                          child: MorphSibling(
                            tag: 'animated-paint-surface',
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
      'when sibling paint changes during a flight, it should not rebuild the Morph overlay',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('paint-only-boundary');
        final siblingColor = ValueNotifier<Color>(Colors.red);
        addTearDown(siblingColor.dispose);
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
                          child: MorphSibling(
                            tag: 'overlay-rebuild-surface',
                            child: ValueListenableBuilder<Color>(
                              valueListenable: siblingColor,
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

        siblingColor.value = Colors.green;
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
      'when an ancestor transform animates during a flight, it should paint the sibling at its current position',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('animated-transform-boundary');
        const siblingKey = ValueKey('animated-transform-sibling');
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
                            child: const MorphSibling(
                              tag: 'animated-transform-surface',
                              child: ColoredBox(
                                key: siblingKey,
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
        final sibling = tester.renderObject<RenderBox>(
          find.byKey(siblingKey),
        );
        final currentCenter = sibling.localToGlobal(
          sibling.size.center(Offset.zero),
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
        const siblingKey = ValueKey('dirty-transform-sibling');
        final transform = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 400),
        );
        final siblingColor = ValueNotifier<Color>(Colors.red);
        addTearDown(transform.dispose);
        addTearDown(siblingColor.dispose);
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
                            child: MorphSibling(
                              tag: 'dirty-transform-surface',
                              child: ValueListenableBuilder<Color>(
                                valueListenable: siblingColor,
                                builder: (context, color, child) {
                                  return ColoredBox(
                                    color: color,
                                    child: child,
                                  );
                                },
                                child: const SizedBox(
                                  key: siblingKey,
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
        siblingColor.value = Colors.green;
        transform.value = 0.75;
        await tester.pump(const Duration(milliseconds: 16));
        final sibling = tester.renderObject<RenderBox>(
          find.byKey(siblingKey),
        );

        expect(
          await _pixelColor(
            tester,
            boundaryKey: boundaryKey,
            position: sibling.localToGlobal(
              sibling.size.center(Offset.zero),
            ),
          ),
          const Color(0xFF4CAF50),
        );
      },
    );

    testWidgets(
      'when an ancestor scales and rotates during a flight, it should preserve the sibling placement',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('scaled-rotated-boundary');
        const siblingKey = ValueKey('scaled-rotated-sibling');
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
                              child: const MorphSibling(
                                tag: 'scaled-rotated-surface',
                                child: SizedBox(
                                  key: siblingKey,
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
        final sibling = tester.renderObject<RenderBox>(
          find.byKey(siblingKey),
        );
        final redPosition = sibling.localToGlobal(const Offset(15, 15));
        final greenPosition = sibling.localToGlobal(const Offset(45, 15));

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
      'when a static sibling is projected, it should not repaint on every flight tick',
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
                        child: MorphSibling(
                          tag: 'static-paint-surface',
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
        const siblingKey = ValueKey('overlapping-flight-sibling');
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
                        child: MorphSibling(
                          tag: 'overlapping-flight-2',
                          child: SizedBox(
                            key: siblingKey,
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
        final boundary = _siblingBoundary(
          tester,
          childKey: siblingKey,
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
      'when a flight finishes, it should disable the sibling repaint boundary again',
      (tester) async {
        const siblingKey = ValueKey('conditional-boundary-sibling');
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
                        child: MorphSibling(
                          tag: 'conditional-boundary-surface',
                          child: SizedBox(
                            key: siblingKey,
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
        final boundary = _siblingBoundary(
          tester,
          childKey: siblingKey,
        );
        final duringFlight = boundary.isRepaintBoundary;
        await tester.pumpAndSettle();

        expect((duringFlight, boundary.isRepaintBoundary), (true, false));
      },
    );

    testWidgets(
      'when a sibling is projected, it should retain the source offset layer across flight ticks',
      (tester) async {
        const siblingKey = ValueKey('transform-layer-sibling');
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
                        child: MorphSibling(
                          tag: 'transform-layer-surface',
                          child: SizedBox(
                            key: siblingKey,
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
        final boundary = _siblingBoundary(
          tester,
          childKey: siblingKey,
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
      'when a sibling is projected, it should suppress interaction and semantics only during the flight',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        const siblingKey = ValueKey('interactive-sibling');
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
                        child: MorphSibling(
                          tag: 'interactive-surface',
                          child: Semantics(
                            label: 'Sibling action',
                            button: true,
                            child: GestureDetector(
                              excludeFromSemantics: true,
                              behavior: HitTestBehavior.opaque,
                              onTap: () => taps += 1,
                              child: const SizedBox(
                                key: siblingKey,
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
        final projected = _siblingBoundary(
          tester,
          childKey: siblingKey,
        ).isRepaintBoundary;
        final semanticsDuring = _activeSemanticsLabelCount(
          tester,
          label: 'Sibling action',
        );
        await tester.tap(find.byKey(siblingKey), warnIfMissed: false);
        await tester.pump();
        final tapsDuring = taps;

        await tester.pumpAndSettle();
        await tester.pump();
        final semanticsAfter = _activeSemanticsLabelCount(
          tester,
          label: 'Sibling action',
        );
        await tester.tap(find.byKey(siblingKey), warnIfMissed: false);
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
      'when painting above Morph is disabled, it should preserve interaction and semantics during the flight',
      (tester) async {
        final semantics = tester.ensureSemantics();
        const siblingKey = ValueKey('natural-interactive-sibling');
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
                    children: [
                      Morph(
                        tag: 'natural-interactive-surface',
                        duration: const Duration(milliseconds: 400),
                        child: SizedBox(
                          key: ValueKey(expanded),
                          width: expanded ? 400 : 40,
                          height: expanded ? 300 : 40,
                        ),
                      ),
                      MorphSibling(
                        tag: 'natural-interactive-surface',
                        paintAboveMorph: false,
                        child: Semantics(
                          label: 'Natural sibling action',
                          button: true,
                          child: GestureDetector(
                            excludeFromSemantics: true,
                            behavior: HitTestBehavior.opaque,
                            onTap: () => taps += 1,
                            child: const SizedBox(
                              key: siblingKey,
                              width: 100,
                              height: 50,
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
        final projected = _siblingBoundary(
          tester,
          childKey: siblingKey,
        ).isRepaintBoundary;
        final semanticsDuring = _activeSemanticsLabelCount(
          tester,
          label: 'Natural sibling action',
        );
        await tester.tap(find.byKey(siblingKey), warnIfMissed: false);
        await tester.pump();
        semantics.dispose();

        expect((projected, semanticsDuring, taps), (false, 1, 1));
      },
    );

    testWidgets(
      'when a projected sibling is removed, it should remove the live projection during the flight',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('removal-boundary');
        const siblingKey = ValueKey('removable-sibling');
        var generation = 0;
        var showSibling = true;
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
                        if (showSibling)
                          const Positioned(
                            left: 150,
                            top: 100,
                            child: MorphSibling(
                              tag: 'removal-surface',
                              child: ColoredBox(
                                key: siblingKey,
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
        final wasProjected = _siblingBoundary(
          tester,
          childKey: siblingKey,
        ).isRepaintBoundary;
        update(() => showSibling = false);
        await tester.pump();
        await tester.pump();

        expect(
          (
            wasProjected,
            find.byKey(siblingKey).evaluate().length,
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
      'when a differently tagged Morph flies, it should leave the sibling below that flight',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('unmatched-sibling-boundary');
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
                          curve: Curves.linear,
                          child: SizedBox(
                            key: ValueKey(expanded),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                            child: const ColoredBox(color: Colors.blue),
                          ),
                        ),
                        const Positioned(
                          left: 150,
                          top: 100,
                          child: MorphSibling(
                            tag: 'another-surface',
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
          const Color(0xFF2196F3),
        );
      },
    );

    testWidgets(
      'when an inline transition builder is recreated during a flight, it should keep the sibling visible',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('inline-transition-boundary');
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
                          tag: 'inline-transition-surface',
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.linear,
                          child: SizedBox(
                            key: ValueKey(expanded),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                            child: const ColoredBox(color: Colors.blue),
                          ),
                        ),
                        Positioned(
                          left: 150,
                          top: 100,
                          child: MorphSibling(
                            tag: 'inline-transition-surface',
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: child,
                              );
                            },
                            child: const ColoredBox(
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
        update(() {});
        await tester.pump();

        expect(
          await _pixelColor(
            tester,
            boundaryKey: boundaryKey,
            position: const Offset(200, 125),
          ),
          isNot(const Color(0xFF2196F3)),
        );
      },
    );

    testWidgets(
      'when a non-null transition builder changes during a flight, it should use the replacement at the same progress',
      (tester) async {
        var expanded = false;
        var useReplacement = false;
        Animation<double>? originalAnimation;
        Animation<double>? replacementAnimation;
        double? originalProgress;
        double? replacementProgress;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: [
                      Morph(
                        tag: 'replacement-transition-surface',
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.linear,
                        child: SizedBox(
                          key: ValueKey(expanded),
                          width: expanded ? 400 : 40,
                          height: expanded ? 300 : 40,
                        ),
                      ),
                      MorphSibling(
                        tag: 'replacement-transition-surface',
                        transitionBuilder: useReplacement
                            ? (child, animation) {
                                replacementAnimation = animation;
                                return AnimatedBuilder(
                                  animation: animation,
                                  child: child,
                                  builder: (context, child) {
                                    replacementProgress = animation.value;
                                    return child!;
                                  },
                                );
                              }
                            : (child, animation) {
                                originalAnimation = animation;
                                return AnimatedBuilder(
                                  animation: animation,
                                  child: child,
                                  builder: (context, child) {
                                    originalProgress = animation.value;
                                    return child!;
                                  },
                                );
                              },
                        child: const SizedBox(width: 100, height: 50),
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
        await tester.pump(const Duration(milliseconds: 200));
        final progressBeforeReplacement = originalProgress!;
        update(() => useReplacement = true);
        await tester.pump();

        expect(
          (
            identical(originalAnimation, replacementAnimation),
            progressBeforeReplacement,
            replacementProgress,
          ),
          (true, progressBeforeReplacement, progressBeforeReplacement),
        );
      },
    );

    testWidgets(
      'when a transition builder reads progress, it should receive the Morph visual progress',
      (tester) async {
        var expanded = false;
        var progress = 1.0;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: [
                      Morph(
                        tag: 'curved-surface',
                        duration: const Duration(milliseconds: 400),
                        curve: const Threshold(0.5),
                        child: SizedBox(
                          key: ValueKey(expanded),
                          width: expanded ? 400 : 40,
                          height: expanded ? 300 : 40,
                        ),
                      ),
                      MorphSibling(
                        tag: 'curved-surface',
                        paintAboveMorph: false,
                        transitionBuilder: (child, animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            child: child,
                            builder: (context, child) {
                              progress = animation.value;
                              return child!;
                            },
                          );
                        },
                        child: const SizedBox(width: 100, height: 50),
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
        await tester.pump(const Duration(milliseconds: 200));

        expect(progress, 1);
      },
    );

    testWidgets(
      'when the Morph curve overshoots, it should clamp the sibling transition progress',
      (tester) async {
        var expanded = false;
        var progress = 1.0;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: [
                      Morph(
                        tag: 'overshoot-surface',
                        duration: const Duration(milliseconds: 400),
                        curve: const _OvershootCurve(),
                        child: SizedBox(
                          key: ValueKey(expanded),
                          width: expanded ? 400 : 40,
                          height: expanded ? 300 : 40,
                        ),
                      ),
                      MorphSibling(
                        tag: 'overshoot-surface',
                        transitionBuilder: (child, animation) {
                          return AnimatedBuilder(
                            animation: animation,
                            child: child,
                            builder: (context, child) {
                              progress = animation.value;
                              return child!;
                            },
                          );
                        },
                        child: const SizedBox(width: 100, height: 50),
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
        await tester.pump(const Duration(milliseconds: 200));

        expect(progress, 1);
      },
    );

    testWidgets(
      'when a transition delays its appearance, it should remain hidden before the interval',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('delayed-sibling-boundary');
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
                          tag: 'delayed-surface',
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.linear,
                          child: SizedBox(
                            key: ValueKey(expanded),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                            child: const ColoredBox(color: Colors.blue),
                          ),
                        ),
                        Positioned(
                          left: 150,
                          top: 100,
                          child: MorphSibling(
                            tag: 'delayed-surface',
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: animation,
                                  curve: const Interval(0.8, 1),
                                ),
                                child: child,
                              );
                            },
                            child: const ColoredBox(
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
          const Color(0xFF2196F3),
        );
      },
    );

    testWidgets(
      'when its tag changes during a flight, it should follow the newly matching Morph',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('updated-tag-boundary');
        var expanded = false;
        var siblingTag = 'another-surface';
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
                          tag: 'updated-tag-surface',
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.linear,
                          child: SizedBox(
                            key: ValueKey(expanded),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                            child: const ColoredBox(color: Colors.blue),
                          ),
                        ),
                        Positioned(
                          left: 150,
                          top: 100,
                          child: MorphSibling(
                            tag: siblingTag,
                            child: const ColoredBox(
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
        update(() => siblingTag = 'updated-tag-surface');
        await tester.pump();
        await tester.pump();

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
      'when paintAboveMorph changes during a flight, it should update the sibling paint order',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('updated-paint-order-boundary');
        var expanded = false;
        var paintAboveMorph = false;
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
                          tag: 'updated-paint-order-surface',
                          duration: const Duration(milliseconds: 400),
                          child: SizedBox(
                            key: ValueKey(expanded),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                            child: const ColoredBox(color: Colors.blue),
                          ),
                        ),
                        Positioned(
                          left: 150,
                          top: 100,
                          child: MorphSibling(
                            tag: 'updated-paint-order-surface',
                            paintAboveMorph: paintAboveMorph,
                            child: const ColoredBox(
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
        final naturalColor = await _pixelColor(
          tester,
          boundaryKey: boundaryKey,
          position: const Offset(200, 125),
        );
        update(() => paintAboveMorph = true);
        await tester.pump();
        await tester.pump();
        final projectedColor = await _pixelColor(
          tester,
          boundaryKey: boundaryKey,
          position: const Offset(200, 125),
        );
        update(() => paintAboveMorph = false);
        await tester.pump();
        await tester.pump();
        final restoredColor = await _pixelColor(
          tester,
          boundaryKey: boundaryKey,
          position: const Offset(200, 125),
        );

        expect(
          (naturalColor, projectedColor, restoredColor),
          (
            const Color(0xFF2196F3),
            const Color(0xFFF44336),
            const Color(0xFF2196F3),
          ),
        );
      },
    );

    testWidgets(
      'when a destination sibling first appears, it should start at the matching route Morph progress',
      (tester) async {
        final values = <double>[];
        await tester.pumpWidget(
          _RouteSiblingApp(onDestinationAnimation: values.add),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('push')));
        await tester.pump();

        expect(values.first, 0);
      },
    );

    testWidgets(
      'when a route Morph enters, it should paint the destination sibling above the flight',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('route-boundary');
        await tester.pumpWidget(
          const RepaintBoundary(
            key: boundaryKey,
            child: _RouteSiblingApp(),
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
      'when a route Morph returns, it should paint the revealed sibling above the flight',
      (tester) async {
        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('route-boundary');
        await tester.pumpWidget(
          const RepaintBoundary(
            key: boundaryKey,
            child: _RouteSiblingApp(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('push')));
        await tester.pumpAndSettle();

        Navigator.of(
          tester.element(find.byType(MorphSibling).last),
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

    testWidgets(
      'when a route Morph returns, it should reverse the departing sibling transition',
      (tester) async {
        final values = <double>[];
        await tester.pumpWidget(
          _RouteSiblingApp(onSourceAnimation: values.add),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('push')));
        await tester.pumpAndSettle();
        values.clear();

        Navigator.of(
          tester.element(find.byType(MorphSibling).last),
        ).pop();
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(values.last, closeTo(0.5, 0.05));
      },
    );
  });
}
