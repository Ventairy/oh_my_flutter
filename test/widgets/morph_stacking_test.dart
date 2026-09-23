import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

final _targets = <String, MorphTarget>{};

void main() {
  setUp(_targets.clear);
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
      'when keyed appearances replace and reorder, it should preserve their departing order',
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
        final morphObserver1 = MorphNavigatorObserver();

        final navigatorKey = GlobalKey<NavigatorState>();
        const boundaryKey = ValueKey('nested-boundary');
        _configureView(tester);
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              navigatorObservers: [morphObserver1],
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
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required GlobalKey<NavigatorState> navigatorKey,
  required Key boundaryKey,
}) async {
  final morphObserver1 = MorphNavigatorObserver();

  _configureView(tester);
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        navigatorObservers: [morphObserver1],
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
  final morphObserver1 = MorphNavigatorObserver();

  _configureView(tester);
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(navigatorObservers: [morphObserver1], home: child),
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
}) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 400),
    reverseTransitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _MorphLayerPage(
        lazyBackground: lazyBackground,
        foregroundFirst: foregroundFirst,
        generation: 1,
      );
    },
  );
}

class _MorphLayerPage extends StatefulWidget {
  const new({
    required this.lazyBackground,
    this.foregroundFirst = false,
    this.generation = 0,
  });

  final bool lazyBackground;
  final bool foregroundFirst;
  final int generation;

  @override
  State<_MorphLayerPage> createState() => _MorphLayerPageState();
}

class _MorphLayerPageState extends State<_MorphLayerPage> {
  final MorphTarget _morphTarget1 = _targets.putIfAbsent('foreground', () => MorphTarget(tag: 'foreground'));

  @override
  Widget build(BuildContext context) {
    final children = widget.foregroundFirst ? [_foreground(), _background()] : [_background(), _foreground()];
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: children,
      ),
    );
  }

  Widget _background() {
    if (!widget.lazyBackground) return _BackgroundMorph(generation: widget.generation);
    return LayoutBuilder(
      builder: (context, constraints) => _BackgroundMorph(
        generation: widget.generation,
      ),
    );
  }

  Widget _foreground() {
    return Center(
      child: Morph(
        key: ValueKey<Object>(ValueKey(('foreground', widget.generation))),

        targets: [_morphTarget1],
        child: ColoredBox(
          key: ValueKey(('foreground', widget.generation)),
          color: const Color(0xFFF44336),
          child: const SizedBox.square(dimension: 120),
        ),
      ),
    );
  }
}

class _NestedMorphPage extends StatefulWidget {
  const new({required this.lazyParent});

  final bool lazyParent;

  @override
  State<_NestedMorphPage> createState() => _NestedMorphPageState();
}

class _NestedMorphPageState extends State<_NestedMorphPage> {
  final MorphTarget _morphTarget2 = _targets.putIfAbsent('nested-parent', () => MorphTarget(tag: 'nested-parent'));
  final MorphTarget _morphTarget3 = _targets.putIfAbsent('nested-child', () => MorphTarget(tag: 'nested-child'));

  @override
  Widget build(BuildContext context) {
    final parent = Morph(
      targets: [_morphTarget2],
      child: ColoredBox(
        color: const Color(0xFF2196F3),
        child: Center(
          child: Morph(
            key: ValueKey<Object>(ValueKey(widget.lazyParent)),

            targets: [_morphTarget3],
            child: ColoredBox(
              key: ValueKey(widget.lazyParent),
              color: const Color(0xFFF44336),
              child: const SizedBox.square(dimension: 120),
            ),
          ),
        ),
      ),
    );
    return Scaffold(
      body: widget.lazyParent ? LayoutBuilder(builder: (context, constraints) => parent) : parent,
    );
  }
}

class _ReorderedSameScreenPage extends StatefulWidget {
  const new({
    required this.foregroundFirst,
    required this.generation,
  });

  final bool foregroundFirst;
  final int generation;

  @override
  State<_ReorderedSameScreenPage> createState() => _ReorderedSameScreenPageState();
}

class _ReorderedSameScreenPageState extends State<_ReorderedSameScreenPage> {
  final MorphTarget _morphTarget4 = _targets.putIfAbsent(
    'same-state-background',
    () => MorphTarget(tag: 'same-state-background'),
  );
  final MorphTarget _morphTarget5 = _targets.putIfAbsent(
    'same-state-foreground',
    () => MorphTarget(tag: 'same-state-foreground'),
  );

  @override
  Widget build(BuildContext context) {
    final background = Morph(
      key: ValueKey(('same-state-background-morph', widget.generation)),
      targets: [_morphTarget4],
      child: ColoredBox(
        key: ValueKey(('same-state-background', widget.generation)),
        color: const Color(0xFF2196F3),
      ),
    );
    final foreground = Morph(
      key: ValueKey(('same-state-foreground-morph', widget.generation)),
      targets: [_morphTarget5],
      child: Center(
        key: ValueKey(('same-state-foreground', widget.generation)),
        child: const ColoredBox(
          color: Color(0xFFF44336),
          child: SizedBox.square(dimension: 120),
        ),
      ),
    );
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: widget.foregroundFirst ? [foreground, background] : [background, foreground],
      ),
    );
  }
}

class _BackgroundMorph extends StatefulWidget {
  const new({required this.generation});

  final int generation;

  @override
  State<_BackgroundMorph> createState() => _BackgroundMorphState();
}

class _BackgroundMorphState extends State<_BackgroundMorph> {
  final MorphTarget _morphTarget6 = _targets.putIfAbsent('background', () => MorphTarget(tag: 'background'));

  @override
  Widget build(BuildContext context) {
    return Morph(
      key: ValueKey<Object>(ValueKey(('background', widget.generation))),

      targets: [_morphTarget6],
      child: ColoredBox(
        key: ValueKey(('background', widget.generation)),
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
