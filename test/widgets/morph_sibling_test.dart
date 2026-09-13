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

class _RouteSiblingApp extends StatefulWidget {
  const _RouteSiblingApp({
    this.onSourceAnimation,
    this.onDestinationAnimation,
    this.morphDuration,
    this.useUncurved = false,
  });

  final ValueChanged<double>? onSourceAnimation;
  final ValueChanged<double>? onDestinationAnimation;
  final Duration? morphDuration;
  final bool useUncurved;

  @override
  State<_RouteSiblingApp> createState() => _RouteSiblingAppState();
}

class _RouteSiblingAppState extends State<_RouteSiblingApp> {
  final _morphTarget1 = MorphTarget(tag: 'route-surface');
  final _morphTarget2 = MorphTarget(tag: 'route-surface');
  final _morphObserver1 = MorphNavigatorObserver();

  Widget _buildSourceSibling() {
    return Positioned(
      left: 150,
      top: 100,
      child: MorphSibling(
        target: _morphTarget1,
        transitionBuilder: widget.onSourceAnimation == null
            ? null
            : (child, animation, uncurvedAnimation) {
                final selectedAnimation = widget.useUncurved ? uncurvedAnimation : animation;
                return AnimatedBuilder(
                  animation: selectedAnimation,
                  builder: (context, child) {
                    widget.onSourceAnimation!(selectedAnimation.value);
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
      navigatorObservers: [_morphObserver1],
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Stack(
              children: [
                Morph(
                  animateChildChanges: true,
                  target: _morphTarget1,
                  duration: widget.morphDuration,
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
                                    animateChildChanges: true,
                                    target: _morphTarget2,
                                    duration: widget.morphDuration,
                                    child: Container(color: Colors.blue),
                                  ),
                                  Positioned(
                                    left: 150,
                                    top: 100,
                                    child: MorphSibling(
                                      target: _morphTarget2,
                                      transitionBuilder: widget.onDestinationAnimation == null
                                          ? null
                                          : (child, animation, uncurvedAnimation) {
                                              final selectedAnimation = widget.useUncurved
                                                  ? uncurvedAnimation
                                                  : animation;
                                              return AnimatedBuilder(
                                                animation: selectedAnimation,
                                                builder: (context, child) {
                                                  widget.onDestinationAnimation!(selectedAnimation.value);
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
        final morphTarget3 = MorphTarget(tag: 'surface');
        final morphObserver1 = MorphNavigatorObserver();

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
              navigatorObservers: [morphObserver1],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: [
                        Morph(
                          animateChildChanges: true,
                          target: morphTarget3,
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
                            target: morphTarget3,
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
          const Color(0xFFF44336),
        );
      },
    );

    testWidgets(
      'when painting above Morph is disabled, it should keep the sibling in its natural paint order',
      (tester) async {
        final morphTarget4 = MorphTarget(tag: 'natural-order-surface');
        final morphObserver1 = MorphNavigatorObserver();

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
              navigatorObservers: [morphObserver1],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: [
                        Morph(
                          animateChildChanges: true,
                          target: morphTarget4,
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
                            target: morphTarget4,
                            paintOnTop: false,
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
      'when a later differently tagged Morph flies, it should paint above the opted-in sibling',
      (tester) async {
        final morphTarget5 = MorphTarget(tag: 'lower-surface');
        final morphTarget6 = MorphTarget(tag: 'upper-surface');
        final morphObserver1 = MorphNavigatorObserver();

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
              navigatorObservers: [morphObserver1],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: [
                        Morph(
                          animateChildChanges: true,
                          target: morphTarget5,
                          duration: const Duration(milliseconds: 400),
                          child: SizedBox(
                            key: ValueKey(('lower', expanded)),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                            child: const ColoredBox(color: Colors.blue),
                          ),
                        ),
                        Positioned(
                          left: 150,
                          top: 100,
                          child: MorphSibling(
                            target: morphTarget5,
                            child: const ColoredBox(
                              color: Colors.red,
                              child: SizedBox(width: 100, height: 50),
                            ),
                          ),
                        ),
                        Morph(
                          animateChildChanges: true,
                          target: morphTarget6,
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
        final morphTarget7 = MorphTarget(tag: 'shadow-surface');
        final morphObserver1 = MorphNavigatorObserver();

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
              navigatorObservers: [morphObserver1],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: [
                        Morph(
                          animateChildChanges: true,
                          target: morphTarget7,
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
                            target: morphTarget7,
                            child: const DecoratedBox(
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
        final morphTarget8 = MorphTarget(tag: 'multiple-surface');
        final morphObserver1 = MorphNavigatorObserver();

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
              navigatorObservers: [morphObserver1],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: <Widget>[
                        Morph(
                          animateChildChanges: true,
                          target: morphTarget8,
                          duration: const Duration(milliseconds: 400),
                          child: SizedBox(
                            key: ValueKey<bool>(expanded),
                            width: expanded ? 400 : 40,
                            height: expanded ? 300 : 40,
                            child: const ColoredBox(color: Colors.blue),
                          ),
                        ),
                        Positioned(
                          left: 100,
                          top: 100,
                          child: MorphSibling(
                            target: morphTarget8,
                            child: const ColoredBox(
                              color: Colors.red,
                              child: SizedBox(width: 100, height: 50),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 150,
                          top: 100,
                          child: MorphSibling(
                            target: morphTarget8,
                            child: const ColoredBox(
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
        final morphTarget9 = MorphTarget(tag: 'live-surface');
        final morphObserver1 = MorphNavigatorObserver();

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
              navigatorObservers: [morphObserver1],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: [
                        Morph(
                          animateChildChanges: true,
                          target: morphTarget9,
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
                            target: morphTarget9,
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
        final morphTarget10 = MorphTarget(tag: 'animated-paint-surface');
        final morphObserver1 = MorphNavigatorObserver();

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
              navigatorObservers: [morphObserver1],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: <Widget>[
                        Morph(
                          animateChildChanges: true,
                          target: morphTarget10,
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
                            target: morphTarget10,
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
        final morphTarget11 = MorphTarget(tag: 'overlay-rebuild-surface');
        final morphObserver1 = MorphNavigatorObserver();

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
              navigatorObservers: [morphObserver1],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: <Widget>[
                        Morph(
                          animateChildChanges: true,
                          target: morphTarget11,
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
                            target: morphTarget11,
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
        final morphTarget12 = MorphTarget(tag: 'animated-transform-surface');
        final morphObserver1 = MorphNavigatorObserver();

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
              navigatorObservers: [morphObserver1],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: <Widget>[
                        Morph(
                          animateChildChanges: true,
                          target: morphTarget12,
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
                              target: morphTarget12,
                              child: const ColoredBox(
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
        final morphTarget13 = MorphTarget(tag: 'dirty-transform-surface');
        final morphObserver1 = MorphNavigatorObserver();

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
              navigatorObservers: [morphObserver1],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: <Widget>[
                        Morph(
                          animateChildChanges: true,
                          target: morphTarget13,
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
                              target: morphTarget13,
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
        final morphTarget14 = MorphTarget(tag: 'scaled-rotated-surface');
        final morphObserver1 = MorphNavigatorObserver();

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
              navigatorObservers: [morphObserver1],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: <Widget>[
                        Morph(
                          animateChildChanges: true,
                          target: morphTarget14,
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
                              child: MorphSibling(
                                target: morphTarget14,
                                child: const SizedBox(
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
        final morphTarget15 = MorphTarget(tag: 'static-paint-surface');
        final morphObserver1 = MorphNavigatorObserver();

        final paintCounter = _PaintCounter();
        var expanded = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [morphObserver1],
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: <Widget>[
                      Morph(
                        animateChildChanges: true,
                        target: morphTarget15,
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
                          target: morphTarget15,
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
        final morphTarget16 = <Object, MorphTarget>{};
        final morphObserver1 = MorphNavigatorObserver();

        const siblingKey = ValueKey('overlapping-flight-sibling');
        var expanded = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [morphObserver1],
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: <Widget>[
                      for (var index = 0; index < 3; index += 1)
                        Morph(
                          animateChildChanges: true,
                          target: morphTarget16.putIfAbsent(
                            'overlapping-flight-$index',
                            () => MorphTarget(tag: 'overlapping-flight-$index'),
                          ),
                          duration: Duration(
                            milliseconds: index < 2 ? 180 : 600,
                          ),
                          child: SizedBox(
                            key: ValueKey<(int, bool)>((index, expanded)),
                            width: expanded ? 300 : 40,
                            height: expanded ? 200 : 40,
                          ),
                        ),
                      Positioned(
                        left: 150,
                        top: 100,
                        child: MorphSibling(
                          target: morphTarget16.putIfAbsent(
                            'overlapping-flight-2',
                            () => MorphTarget(tag: 'overlapping-flight-2'),
                          ),
                          child: const SizedBox(
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
        final morphTarget17 = MorphTarget(tag: 'conditional-boundary-surface');
        final morphObserver1 = MorphNavigatorObserver();

        const siblingKey = ValueKey('conditional-boundary-sibling');
        var expanded = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [morphObserver1],
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: <Widget>[
                      Morph(
                        animateChildChanges: true,
                        target: morphTarget17,
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
                          target: morphTarget17,
                          child: const SizedBox(
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
        final morphTarget18 = MorphTarget(tag: 'transform-layer-surface');
        final morphObserver1 = MorphNavigatorObserver();

        const siblingKey = ValueKey('transform-layer-sibling');
        var expanded = false;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [morphObserver1],
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: <Widget>[
                      Morph(
                        animateChildChanges: true,
                        target: morphTarget18,
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
                          target: morphTarget18,
                          child: const SizedBox(
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
        final morphTarget19 = MorphTarget(tag: 'interactive-surface');
        final morphObserver1 = MorphNavigatorObserver();

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
            navigatorObservers: [morphObserver1],
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: <Widget>[
                      Morph(
                        animateChildChanges: true,
                        target: morphTarget19,
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
                          target: morphTarget19,
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
        final morphTarget20 = MorphTarget(tag: 'natural-interactive-surface');
        final morphObserver1 = MorphNavigatorObserver();

        final semantics = tester.ensureSemantics();
        const siblingKey = ValueKey('natural-interactive-sibling');
        var expanded = false;
        var taps = 0;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [morphObserver1],
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: [
                      Morph(
                        animateChildChanges: true,
                        target: morphTarget20,
                        duration: const Duration(milliseconds: 400),
                        child: SizedBox(
                          key: ValueKey(expanded),
                          width: expanded ? 400 : 40,
                          height: expanded ? 300 : 40,
                        ),
                      ),
                      MorphSibling(
                        target: morphTarget20,
                        paintOnTop: false,
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
        final morphTarget21 = MorphTarget(tag: 'removal-surface');
        final morphObserver1 = MorphNavigatorObserver();

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
              navigatorObservers: [morphObserver1],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: <Widget>[
                        Morph(
                          animateChildChanges: true,
                          target: morphTarget21,
                          duration: const Duration(milliseconds: 400),
                          child: SizedBox(
                            key: ValueKey<int>(generation),
                            width: 400,
                            height: 300,
                            child: const ColoredBox(color: Colors.blue),
                          ),
                        ),
                        if (showSibling)
                          Positioned(
                            left: 150,
                            top: 100,
                            child: MorphSibling(
                              target: morphTarget21,
                              child: const ColoredBox(
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
        final morphTarget22 = MorphTarget(tag: 'surface');
        final unmatchedTarget = MorphTarget(tag: 'another-surface');
        final morphObserver1 = MorphNavigatorObserver();

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
              navigatorObservers: [morphObserver1],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: [
                        Morph(
                          animateChildChanges: true,
                          target: morphTarget22,
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
                            target: unmatchedTarget,
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
      'when an inline transition builder is recreated during a flight, it should keep the sibling visible',
      (tester) async {
        final morphTarget23 = MorphTarget(tag: 'inline-transition-surface');
        final morphObserver1 = MorphNavigatorObserver();

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
              navigatorObservers: [morphObserver1],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: [
                        Morph(
                          animateChildChanges: true,
                          target: morphTarget23,
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
                            target: morphTarget23,
                            transitionBuilder: (child, animation, uncurvedAnimation) {
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
        final morphTarget24 = MorphTarget(tag: 'replacement-transition-surface');
        final morphObserver1 = MorphNavigatorObserver();

        var expanded = false;
        var useReplacement = false;
        Animation<double>? originalAnimation;
        Animation<double>? replacementAnimation;
        double? originalProgress;
        double? replacementProgress;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [morphObserver1],
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: [
                      Morph(
                        animateChildChanges: true,
                        target: morphTarget24,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.linear,
                        child: SizedBox(
                          key: ValueKey(expanded),
                          width: expanded ? 400 : 40,
                          height: expanded ? 300 : 40,
                        ),
                      ),
                      MorphSibling(
                        target: morphTarget24,
                        transitionBuilder: useReplacement
                            ? (child, animation, uncurvedAnimation) {
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
                            : (child, animation, uncurvedAnimation) {
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
      'when a non-null transition builder changes during a flight, it should use the replacement at the same uncurved progress',
      (tester) async {
        final morphTarget25 = MorphTarget(tag: 'replacement-transition-surface');
        final morphObserver1 = MorphNavigatorObserver();

        var expanded = false;
        var useReplacement = false;
        Animation<double>? originalAnimation;
        Animation<double>? replacementAnimation;
        double? originalProgress;
        double? replacementProgress;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [morphObserver1],
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: [
                      Morph(
                        animateChildChanges: true,
                        target: morphTarget25,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.linear,
                        child: SizedBox(
                          key: ValueKey(expanded),
                          width: expanded ? 400 : 40,
                          height: expanded ? 300 : 40,
                        ),
                      ),
                      MorphSibling(
                        target: morphTarget25,
                        transitionBuilder: useReplacement
                            ? (child, animation, uncurvedAnimation) {
                                replacementAnimation = uncurvedAnimation;
                                return AnimatedBuilder(
                                  animation: uncurvedAnimation,
                                  child: child,
                                  builder: (context, child) {
                                    replacementProgress = uncurvedAnimation.value;
                                    return child!;
                                  },
                                );
                              }
                            : (child, animation, uncurvedAnimation) {
                                originalAnimation = uncurvedAnimation;
                                return AnimatedBuilder(
                                  animation: uncurvedAnimation,
                                  child: child,
                                  builder: (context, child) {
                                    originalProgress = uncurvedAnimation.value;
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
        final morphTarget26 = MorphTarget(tag: 'curved-surface');
        final arrivalTarget = MorphTarget(tag: 'curved-surface');
        final morphObserver1 = MorphNavigatorObserver();

        var expanded = false;
        var progress = 1.0;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [morphObserver1],
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: [
                      Morph(
                        animateChildChanges: true,
                        target: expanded ? arrivalTarget : morphTarget26,
                        duration: const Duration(milliseconds: 400),
                        curve: const Threshold(0.5),
                        child: SizedBox(
                          key: ValueKey(expanded),
                          width: expanded ? 400 : 40,
                          height: expanded ? 300 : 40,
                        ),
                      ),
                      MorphSibling(
                        target: expanded ? arrivalTarget : morphTarget26,
                        paintOnTop: false,
                        transitionBuilder: (child, animation, uncurvedAnimation) {
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
      'when a transition builder reads progress, it should expose independent uncurved progress',
      (tester) async {
        final morphTarget27 = MorphTarget(tag: 'curved-surface');
        final arrivalTarget = MorphTarget(tag: 'curved-surface');
        final morphObserver1 = MorphNavigatorObserver();

        var expanded = false;
        var progress = (1.0, 1.0);
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [morphObserver1],
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: [
                      Morph(
                        animateChildChanges: true,
                        target: expanded ? arrivalTarget : morphTarget27,
                        duration: const Duration(milliseconds: 400),
                        curve: const Threshold(0.5),
                        child: SizedBox(
                          key: ValueKey(expanded),
                          width: expanded ? 400 : 40,
                          height: expanded ? 300 : 40,
                        ),
                      ),
                      MorphSibling(
                        target: expanded ? arrivalTarget : morphTarget27,
                        paintOnTop: false,
                        transitionBuilder: (child, animation, uncurvedAnimation) {
                          return AnimatedBuilder(
                            animation: uncurvedAnimation,
                            child: child,
                            builder: (context, child) {
                              progress = (animation.value, uncurvedAnimation.value);
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

        expect(progress, (1.0, 0.5));
      },
    );

    testWidgets(
      'when a flight completes, it should settle both sibling animations at one',
      (tester) async {
        final morphTarget28 = MorphTarget(tag: 'curved-surface');
        final arrivalTarget = MorphTarget(tag: 'curved-surface');
        final morphObserver1 = MorphNavigatorObserver();

        var expanded = false;
        var progress = (1.0, 1.0);
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [morphObserver1],
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: [
                      Morph(
                        animateChildChanges: true,
                        target: expanded ? arrivalTarget : morphTarget28,
                        duration: const Duration(milliseconds: 400),
                        curve: const Threshold(0.5),
                        child: SizedBox(
                          key: ValueKey(expanded),
                          width: expanded ? 400 : 40,
                          height: expanded ? 300 : 40,
                        ),
                      ),
                      MorphSibling(
                        target: expanded ? arrivalTarget : morphTarget28,
                        paintOnTop: false,
                        transitionBuilder: (child, animation, uncurvedAnimation) {
                          return AnimatedBuilder(
                            animation: uncurvedAnimation,
                            child: child,
                            builder: (context, child) {
                              progress = (animation.value, uncurvedAnimation.value);
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
        await tester.pumpAndSettle();

        expect(progress, (1.0, 1.0));
      },
    );

    testWidgets(
      'when the Morph curve overshoots, it should clamp the sibling transition progress',
      (tester) async {
        final morphTarget29 = MorphTarget(tag: 'overshoot-surface');
        final arrivalTarget = MorphTarget(tag: 'overshoot-surface');
        final morphObserver1 = MorphNavigatorObserver();

        var expanded = false;
        var progress = 1.0;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [morphObserver1],
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Stack(
                    children: [
                      Morph(
                        animateChildChanges: true,
                        target: expanded ? arrivalTarget : morphTarget29,
                        duration: const Duration(milliseconds: 400),
                        curve: const _OvershootCurve(),
                        child: SizedBox(
                          key: ValueKey(expanded),
                          width: expanded ? 400 : 40,
                          height: expanded ? 300 : 40,
                        ),
                      ),
                      MorphSibling(
                        target: expanded ? arrivalTarget : morphTarget29,
                        transitionBuilder: (child, animation, uncurvedAnimation) {
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
        final morphTarget30 = MorphTarget(tag: 'delayed-surface');
        final arrivalTarget = MorphTarget(tag: 'delayed-surface');
        final morphObserver1 = MorphNavigatorObserver();

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
              navigatorObservers: [morphObserver1],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: [
                        Morph(
                          animateChildChanges: true,
                          target: expanded ? arrivalTarget : morphTarget30,
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
                            target: expanded ? arrivalTarget : morphTarget30,
                            transitionBuilder: (child, animation, uncurvedAnimation) {
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
      'when an uncurved transition delays its appearance, it should remain hidden before the interval',
      (tester) async {
        final morphTarget31 = MorphTarget(tag: 'delayed-surface');
        final arrivalTarget = MorphTarget(tag: 'delayed-surface');
        final morphObserver1 = MorphNavigatorObserver();

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
              navigatorObservers: [morphObserver1],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: [
                        Morph(
                          animateChildChanges: true,
                          target: expanded ? arrivalTarget : morphTarget31,
                          duration: const Duration(milliseconds: 400),
                          curve: const Threshold(0.1),
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
                            target: expanded ? arrivalTarget : morphTarget31,
                            transitionBuilder: (child, animation, uncurvedAnimation) {
                              return FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: uncurvedAnimation,
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
      'when its target changes during a flight, it should follow the newly associated Morph',
      (tester) async {
        final morphTarget32 = MorphTarget(tag: 'updated-tag-surface');
        final morphObserver1 = MorphNavigatorObserver();

        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('updated-tag-boundary');
        var expanded = false;
        var siblingTarget = MorphTarget(tag: 'another-surface');
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              navigatorObservers: [morphObserver1],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: [
                        Morph(
                          animateChildChanges: true,
                          target: morphTarget32,
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
                            target: siblingTarget,
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
        update(() => siblingTarget = morphTarget32);
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
      'when paintOnTop changes during a flight, it should update the sibling paint order',
      (tester) async {
        final morphTarget33 = MorphTarget(tag: 'updated-paint-order-surface');
        final morphObserver1 = MorphNavigatorObserver();

        tester.view.physicalSize = const Size(400, 300);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const boundaryKey = ValueKey('updated-paint-order-boundary');
        var expanded = false;
        var paintOnTop = false;
        late StateSetter update;
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              navigatorObservers: [morphObserver1],
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return Stack(
                      children: [
                        Morph(
                          animateChildChanges: true,
                          target: morphTarget33,
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
                            target: morphTarget33,
                            paintOnTop: paintOnTop,
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
        update(() => paintOnTop = true);
        await tester.pump();
        await tester.pump();
        final projectedColor = await _pixelColor(
          tester,
          boundaryKey: boundaryKey,
          position: const Offset(200, 125),
        );
        update(() => paintOnTop = false);
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
      'when a destination sibling first appears with uncurved timing, it should start at the matching route Morph progress',
      (tester) async {
        final values = <double>[];
        await tester.pumpWidget(
          _RouteSiblingApp(useUncurved: true, onDestinationAnimation: values.add),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('push')));
        await tester.pump();

        expect(values.first, 0);
      },
    );

    testWidgets(
      'when a route Morph supplies duration, its sibling should follow the independent Morph clock',
      (tester) async {
        final values = <double>[];
        await tester.pumpWidget(
          _RouteSiblingApp(
            morphDuration: const Duration(milliseconds: 800),
            onDestinationAnimation: values.add,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('push')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(values.last, closeTo(0.25, 0.05));
      },
    );

    testWidgets(
      'when a route Morph supplies duration with uncurved timing, its sibling should follow the independent Morph clock',
      (tester) async {
        final values = <double>[];
        await tester.pumpWidget(
          _RouteSiblingApp(
            useUncurved: true,
            morphDuration: const Duration(milliseconds: 800),
            onDestinationAnimation: values.add,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('push')));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(values.last, closeTo(0.25, 0.05));
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
    testWidgets(
      'when a route Morph returns with uncurved timing, it should reverse the departing sibling transition',
      (tester) async {
        final values = <double>[];
        await tester.pumpWidget(
          _RouteSiblingApp(useUncurved: true, onSourceAnimation: values.add),
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
