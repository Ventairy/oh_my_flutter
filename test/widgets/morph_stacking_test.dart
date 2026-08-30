import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('Morph stacking', () {
    testWidgets(
      'when a lower destination registers after an overlapping foreground, it should preserve departing order during a route push',
      (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        const boundaryKey = ValueKey('route-push-boundary');
        await _pumpApp(
          tester,
          navigatorKey: navigatorKey,
          boundaryKey: boundaryKey,
        );
        navigatorKey.currentState!.push(_route(lazyBackground: true));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          await _centerPixel(tester, boundaryKey),
          const Color(0xFFF44336),
        );
      },
    );

    testWidgets(
      'when a lower source registered after an overlapping foreground, it should preserve departing order during a route pop',
      (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        const boundaryKey = ValueKey('route-pop-boundary');
        await _pumpApp(
          tester,
          navigatorKey: navigatorKey,
          boundaryKey: boundaryKey,
        );
        navigatorKey.currentState!.push(_route(lazyBackground: true));
        await tester.pumpAndSettle();

        navigatorKey.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          await _centerPixel(tester, boundaryKey),
          const Color(0xFFF44336),
        );
      },
    );

    testWidgets(
      'when same-screen destinations register out of paint order, it should preserve departing order',
      (tester) async {
        const boundaryKey = ValueKey('same-screen-boundary');
        var lazyBackground = false;
        late StateSetter update;
        await _pumpBoundary(
          tester,
          boundaryKey: boundaryKey,
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return _MorphLayerPage(
                lazyBackground: lazyBackground,
                generation: lazyBackground ? 1 : 0,
              );
            },
          ),
        );

        update(() => lazyBackground = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        expect(
          await _centerPixel(tester, boundaryKey),
          const Color(0xFFF44336),
        );
      },
    );

    testWidgets(
      'when keyed same-state endpoints reorder, it should preserve their departing order',
      (tester) async {
        const boundaryKey = ValueKey('same-state-order-boundary');
        var foregroundFirst = false;
        late StateSetter update;
        await _pumpBoundary(
          tester,
          boundaryKey: boundaryKey,
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return _ReorderedSameScreenPage(
                foregroundFirst: foregroundFirst,
                generation: foregroundFirst ? 1 : 0,
              );
            },
          ),
        );

        update(() => foregroundFirst = true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        expect(
          await _centerPixel(tester, boundaryKey),
          const Color(0xFFF44336),
        );
      },
    );

    testWidgets(
      'when destination overlap differs, it should keep the departing order during the flight',
      (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        const boundaryKey = ValueKey('conflicting-order-boundary');
        await _pumpApp(
          tester,
          navigatorKey: navigatorKey,
          boundaryKey: boundaryKey,
        );
        navigatorKey.currentState!.push(
          _route(
            lazyBackground: false,
            foregroundFirst: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          await _centerPixel(tester, boundaryKey),
          const Color(0xFFF44336),
        );
      },
    );

    testWidgets(
      'when a route flight retargets during pop, it should keep its existing order',
      (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        const boundaryKey = ValueKey('retarget-boundary');
        await _pumpApp(
          tester,
          navigatorKey: navigatorKey,
          boundaryKey: boundaryKey,
        );
        navigatorKey.currentState!.push(_route(lazyBackground: true));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        navigatorKey.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          await _centerPixel(tester, boundaryKey),
          const Color(0xFFF44336),
        );
      },
    );

    testWidgets(
      'when nested Morphs fly together, it should paint the descendant above its ancestor',
      (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        const boundaryKey = ValueKey('nested-boundary');
        _configureView(tester);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              navigatorKey: navigatorKey,
              home: const _NestedMorphPage(lazyParent: false),
            ),
          ),
        );
        await tester.pumpAndSettle();
        navigatorKey.currentState!.push(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 400),
            pageBuilder: (context, animation, secondaryAnimation) {
              return const _NestedMorphPage(lazyParent: true);
            },
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          await _centerPixel(tester, boundaryKey),
          const Color(0xFFF44336),
        );
      },
    );

    testWidgets(
      'when MorphSibling overlaps its ordered flight, it should remain above that flight',
      (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        const boundaryKey = ValueKey('morph-sibling-boundary');
        await _pumpApp(
          tester,
          navigatorKey: navigatorKey,
          boundaryKey: boundaryKey,
        );
        navigatorKey.currentState!.push(
          _route(
            lazyBackground: true,
            showMorphSibling: true,
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(
          await _centerPixel(tester, boundaryKey),
          const Color(0xFF4CAF50),
        );
      },
    );
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required GlobalKey<NavigatorState> navigatorKey,
  required Key boundaryKey,
}) async {
  _configureView(tester);
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        home: const _MorphLayerPage(lazyBackground: false),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpBoundary(
  WidgetTester tester, {
  required Key boundaryKey,
  required Widget child,
}) async {
  _configureView(tester);
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
}

void _configureView(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

PageRoute<void> _route({
  required bool lazyBackground,
  bool foregroundFirst = false,
  bool showMorphSibling = false,
}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _MorphLayerPage(
        lazyBackground: lazyBackground,
        foregroundFirst: foregroundFirst,
        generation: 1,
        showMorphSibling: showMorphSibling,
      );
    },
  );
}

class _MorphLayerPage extends StatelessWidget {
  const _MorphLayerPage({
    required this.lazyBackground,
    this.foregroundFirst = false,
    this.generation = 0,
    this.showMorphSibling = false,
  });

  final bool lazyBackground;
  final bool foregroundFirst;
  final int generation;
  final bool showMorphSibling;

  @override
  Widget build(BuildContext context) {
    final children = foregroundFirst ? [_foreground(), _background()] : [_background(), _foreground()];
    if (showMorphSibling) {
      children.add(
        const Center(
          child: MorphSibling(
            tag: 'foreground',
            child: ColoredBox(
              color: Color(0xFF4CAF50),
              child: SizedBox.square(dimension: 40),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: children,
      ),
    );
  }

  Widget _background() {
    if (!lazyBackground) return _BackgroundMorph(generation: generation);
    return LayoutBuilder(
      builder: (context, constraints) => _BackgroundMorph(
        generation: generation,
      ),
    );
  }

  Widget _foreground() {
    return Center(
      child: Morph(
        tag: 'foreground',
        child: ColoredBox(
          key: ValueKey(('foreground', generation)),
          color: const Color(0xFFF44336),
          child: const SizedBox.square(dimension: 120),
        ),
      ),
    );
  }
}

class _NestedMorphPage extends StatelessWidget {
  const _NestedMorphPage({required this.lazyParent});

  final bool lazyParent;

  @override
  Widget build(BuildContext context) {
    final parent = Morph(
      tag: 'nested-parent',
      child: ColoredBox(
        color: const Color(0xFF2196F3),
        child: Center(
          child: Morph(
            tag: 'nested-child',
            child: ColoredBox(
              key: ValueKey(lazyParent),
              color: const Color(0xFFF44336),
              child: const SizedBox.square(dimension: 120),
            ),
          ),
        ),
      ),
    );
    return Scaffold(
      body: lazyParent ? LayoutBuilder(builder: (context, constraints) => parent) : parent,
    );
  }
}

class _ReorderedSameScreenPage extends StatelessWidget {
  const _ReorderedSameScreenPage({
    required this.foregroundFirst,
    required this.generation,
  });

  final bool foregroundFirst;
  final int generation;

  @override
  Widget build(BuildContext context) {
    final background = Morph(
      key: const ValueKey('same-state-background-morph'),
      tag: 'same-state-background',
      child: ColoredBox(
        key: ValueKey(('same-state-background', generation)),
        color: const Color(0xFF2196F3),
      ),
    );
    final foreground = Morph(
      key: const ValueKey('same-state-foreground-morph'),
      tag: 'same-state-foreground',
      child: Center(
        key: ValueKey(('same-state-foreground', generation)),
        child: const ColoredBox(
          color: Color(0xFFF44336),
          child: SizedBox.square(dimension: 120),
        ),
      ),
    );
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: foregroundFirst ? [foreground, background] : [background, foreground],
      ),
    );
  }
}

class _BackgroundMorph extends StatelessWidget {
  const _BackgroundMorph({required this.generation});

  final int generation;

  @override
  Widget build(BuildContext context) {
    return Morph(
      tag: 'background',
      child: ColoredBox(
        key: ValueKey(('background', generation)),
        color: const Color(0xFF2196F3),
        child: const SizedBox.expand(),
      ),
    );
  }
}

Future<Color> _centerPixel(WidgetTester tester, Key boundaryKey) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      const x = 200;
      const y = 200;
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
