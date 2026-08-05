import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

Widget _testApp({
  required Widget child,
  bool disableAnimations = false,
  bool tickersEnabled = true,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Directionality(
      textDirection: textDirection,
      child: TickerMode(
        enabled: tickersEnabled,
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );
}

Widget _child(
  Key key, {
  required double width,
  required double height,
  VoidCallback? onTap,
  String? semanticsLabel,
}) {
  return SizedBox(
    width: width,
    height: height,
    child: Semantics(
      label: semanticsLabel,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
      ),
    ),
  );
}

Widget _horizontalMarquee({
  MarqueeDirection direction = MarqueeDirection.right,
  Duration duration = const Duration(seconds: 1),
  double spacing = 10,
  bool interactive = false,
  bool infinity = false,
  bool disableAnimations = false,
  bool tickersEnabled = true,
  List<Widget>? children,
}) {
  return _testApp(
    disableAnimations: disableAnimations,
    tickersEnabled: tickersEnabled,
    child: SizedBox(
      width: 200,
      child: Marquee(
        direction: direction,
        duration: duration,
        spacing: spacing,
        interactive: interactive,
        infinity: infinity,
        children:
            children ??
            <Widget>[
              _child(const ValueKey('first'), width: 20, height: 20),
              _child(const ValueKey('second'), width: 30, height: 30),
            ],
      ),
    ),
  );
}

class _InitializationCounter extends StatefulWidget {
  const _InitializationCounter({required this.onInit, super.key});

  final VoidCallback onInit;

  @override
  State<_InitializationCounter> createState() => _InitializationCounterState();
}

class _InitializationCounterState extends State<_InitializationCounter> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 20, height: 20);
}

class _PaintCounter extends CustomPainter {
  int count = 0;

  @override
  void paint(Canvas canvas, Size size) {
    count += 1;
  }

  @override
  bool shouldRepaint(covariant _PaintCounter oldDelegate) => false;
}

void main() {
  group('Marquee configuration', () {
    test('when defaults are used, it should expose the documented values', () {
      const marquee = Marquee(
        children: <Widget>[SizedBox(), SizedBox()],
      );

      expect(
        (
          marquee.direction,
          marquee.duration,
          marquee.spacing,
          marquee.width,
          marquee.height,
          marquee.interactive,
          marquee.infinity,
        ),
        (
          MarqueeDirection.right,
          const Duration(seconds: 1),
          0,
          null,
          null,
          false,
          true,
        ),
      );
    });

    testWidgets('when fewer than two children are provided, it should reject mounting', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: const Marquee(children: <Widget>[SizedBox()]),
        ),
      );

      expect(tester.takeException(), isArgumentError);
    });

    testWidgets('when duration is not positive, it should reject mounting', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: const Marquee(
            duration: Duration.zero,
            children: <Widget>[SizedBox(), SizedBox()],
          ),
        ),
      );

      expect(tester.takeException(), isArgumentError);
    });

    test('when spacing is negative, it should reject construction', () {
      expect(
        () => Marquee(
          spacing: -1,
          children: const <Widget>[SizedBox(), SizedBox()],
        ),
        throwsAssertionError,
      );
    });

    test('when a dimension is infinite, it should reject construction', () {
      expect(
        () => Marquee(
          width: double.infinity,
          children: const <Widget>[SizedBox(), SizedBox()],
        ),
        throwsAssertionError,
      );
    });
  });

  group('Marquee layout', () {
    testWidgets('when horizontal dimensions are omitted, it should fill width and use the tallest child', (
      tester,
    ) async {
      await tester.pumpWidget(_horizontalMarquee(disableAnimations: true));

      expect(tester.getSize(find.byType(Marquee)), const Size(200, 30));
    });

    testWidgets('when vertical dimensions are omitted, it should fill height and use the widest child', (tester) async {
      await tester.pumpWidget(
        _testApp(
          disableAnimations: true,
          child: SizedBox(
            height: 200,
            child: Marquee(
              direction: MarqueeDirection.down,
              spacing: 10,
              children: <Widget>[
                _child(const ValueKey('first'), width: 20, height: 20),
                _child(const ValueKey('second'), width: 30, height: 30),
              ],
            ),
          ),
        ),
      );

      expect(tester.getSize(find.byType(Marquee)), const Size(30, 200));
    });

    testWidgets('when dimensions are supplied, it should use the requested viewport size', (tester) async {
      await tester.pumpWidget(
        _testApp(
          disableAnimations: true,
          child: Marquee(
            width: 120,
            height: 40,
            children: <Widget>[
              _child(const ValueKey('first'), width: 20, height: 20),
              _child(const ValueKey('second'), width: 30, height: 30),
            ],
          ),
        ),
      );

      expect(tester.getSize(find.byType(Marquee)), const Size(120, 40));
    });

    testWidgets('when horizontal width is unbounded and omitted, it should report a layout error', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: const SizedBox(
            width: 100,
            child: Marquee(
              children: <Widget>[SizedBox(), SizedBox()],
            ),
          ),
        ),
      );
      final renderBox = tester.renderObject<RenderBox>(find.byType(Marquee));

      expect(
        () => renderBox.getDryLayout(
          const BoxConstraints(maxHeight: 100),
        ),
        throwsA(
          isA<FlutterError>().having(
            (error) => error.toString(),
            'message',
            contains('bounded width'),
          ),
        ),
      );
    });

    testWidgets('when fixed cross-axis space is too small, it should report an overflow', (tester) async {
      await tester.pumpWidget(
        _testApp(
          disableAnimations: true,
          child: Marquee(
            width: 120,
            height: 10,
            children: <Widget>[
              _child(const ValueKey('first'), width: 20, height: 20),
              _child(const ValueKey('second'), width: 30, height: 30),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isFlutterError);
    });

    testWidgets('when spacing is provided, it should separate adjacent children', (tester) async {
      await tester.pumpWidget(_horizontalMarquee(disableAnimations: true));

      expect(tester.getTopLeft(find.byKey(const ValueKey('second'))).dx, 30);
    });
  });

  group('Marquee motion', () {
    testWidgets('when the animation advances, it should not repaint static children', (tester) async {
      final paintCounter = _PaintCounter();
      await tester.pumpWidget(
        _horizontalMarquee(
          infinity: true,
          children: <Widget>[
            CustomPaint(
              key: const ValueKey('first'),
              painter: paintCounter,
              size: const Size(20, 20),
            ),
            _child(const ValueKey('second'), width: 30, height: 30),
          ],
        ),
      );
      await tester.pump();
      final initialPaintCount = paintCounter.count;
      await tester.pump(const Duration(milliseconds: 250));

      expect(paintCounter.count, initialPaintCount);
    });

    testWidgets('when infinity is enabled, it should duplicate enough children to fill the viewport', (tester) async {
      await tester.pumpWidget(
        _horizontalMarquee(
          infinity: true,
          disableAnimations: true,
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('first')), findsNWidgets(4));
    });

    testWidgets('when a source strip is long, it should mount only the required repeated prefix', (tester) async {
      await tester.pumpWidget(
        _testApp(
          disableAnimations: true,
          child: SizedBox(
            width: 100,
            child: Marquee(
              spacing: 10,
              children: <Widget>[
                _child(const ValueKey('first'), width: 80, height: 20),
                _child(const ValueKey('second'), width: 80, height: 20),
                _child(const ValueKey('third'), width: 80, height: 20),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        (
          find.byKey(const ValueKey('first')).evaluate().length,
          find.byKey(const ValueKey('second')).evaluate().length,
          find.byKey(const ValueKey('third')).evaluate().length,
        ),
        (2, 2, 1),
      );
    });

    testWidgets('when the viewport grows, it should reuse existing repeated wrappers', (tester) async {
      late StateSetter rebuild;
      var width = 100.0;
      final children = <Widget>[
        _child(const ValueKey('first'), width: 20, height: 20),
        _child(const ValueKey('second'), width: 30, height: 30),
      ];
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _testApp(
              disableAnimations: true,
              child: SizedBox(
                width: width,
                child: Marquee(
                  spacing: 10,
                  children: children,
                ),
              ),
            );
          },
        ),
      );
      await tester.pump();
      final marquee = find.byType(Marquee);
      final initialWrappers = find
          .descendant(of: marquee, matching: find.byType(KeyedSubtree))
          .evaluate()
          .map((element) => element.widget)
          .toList();
      rebuild(() => width = 200);
      await tester.pump();
      await tester.pump();
      final grownWrappers = find
          .descendant(of: marquee, matching: find.byType(KeyedSubtree))
          .evaluate()
          .map((element) => element.widget)
          .toList();

      expect(
        List<bool>.generate(
          initialWrappers.length,
          (index) => identical(initialWrappers[index], grownWrappers[index]),
        ),
        everyElement(isTrue),
      );
    });

    testWidgets('when infinity is enabled, it should preserve spacing across repeated sets', (tester) async {
      await tester.pumpWidget(
        _horizontalMarquee(
          infinity: true,
          disableAnimations: true,
        ),
      );
      await tester.pump();
      final firstPositions = find
          .byKey(const ValueKey('first'))
          .evaluate()
          .map((element) => (element.renderObject! as RenderBox).localToGlobal(Offset.zero).dx)
          .toList();
      final secondPositions = find
          .byKey(const ValueKey('second'))
          .evaluate()
          .map((element) => (element.renderObject! as RenderBox).localToGlobal(Offset.zero).dx)
          .toList();

      expect(firstPositions[1] - (secondPositions[0] + 30), 10);
    });

    testWidgets('when an infinite viewport grows, it should mount the additional required children', (tester) async {
      late StateSetter rebuild;
      var width = 100.0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _testApp(
              disableAnimations: true,
              child: SizedBox(
                width: width,
                child: Marquee(
                  spacing: 10,
                  children: <Widget>[
                    _child(const ValueKey('first'), width: 20, height: 20),
                    _child(const ValueKey('second'), width: 30, height: 30),
                  ],
                ),
              ),
            );
          },
        ),
      );
      await tester.pump();
      rebuild(() => width = 250);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const ValueKey('first')), findsNWidgets(5));
    });

    testWidgets('when an infinite loop advances, it should keep repeated sets evenly covering the viewport', (
      tester,
    ) async {
      await tester.pumpWidget(
        _horizontalMarquee(
          direction: MarqueeDirection.left,
          infinity: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final positions = find
          .byKey(const ValueKey('first'))
          .evaluate()
          .map((element) => (element.renderObject! as RenderBox).localToGlobal(Offset.zero).dx.round())
          .toList();

      expect(positions, <int>[-35, 35, 105, 175]);
    });

    testWidgets('when direction is left, it should move toward the negative horizontal edge', (tester) async {
      await tester.pumpWidget(_horizontalMarquee(direction: MarqueeDirection.left));
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.getTopLeft(find.byKey(const ValueKey('first'))).dx, closeTo(70, 0.01));
    });

    testWidgets('when direction is right, it should move toward the positive horizontal edge', (tester) async {
      await tester.pumpWidget(_horizontalMarquee());
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.getTopLeft(find.byKey(const ValueKey('first'))).dx, closeTo(70, 0.01));
    });

    testWidgets('when direction is top, it should move toward the negative vertical edge', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: Marquee(
            direction: MarqueeDirection.top,
            infinity: false,
            width: 30,
            height: 200,
            spacing: 10,
            children: <Widget>[
              _child(const ValueKey('first'), width: 20, height: 20),
              _child(const ValueKey('second'), width: 30, height: 30),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.getTopLeft(find.byKey(const ValueKey('first'))).dy, closeTo(70, 0.01));
    });

    testWidgets('when direction is down, it should move toward the positive vertical edge', (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: Marquee(
            direction: MarqueeDirection.down,
            infinity: false,
            width: 30,
            height: 200,
            spacing: 10,
            children: <Widget>[
              _child(const ValueKey('first'), width: 20, height: 20),
              _child(const ValueKey('second'), width: 30, height: 30),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.getTopLeft(find.byKey(const ValueKey('first'))).dy, closeTo(70, 0.01));
    });

    testWidgets('when a custom duration is provided, it should complete half its path at half the duration', (
      tester,
    ) async {
      await tester.pumpWidget(
        _horizontalMarquee(duration: const Duration(milliseconds: 600)),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.getTopLeft(find.byKey(const ValueKey('first'))).dx, closeTo(70, 0.01));
    });

    testWidgets('when a loop completes, it should restart fully outside the entry edge', (tester) async {
      await tester.pumpWidget(_horizontalMarquee());
      await tester.pump(const Duration(seconds: 1));

      expect(tester.getTopLeft(find.byKey(const ValueKey('first'))).dx, closeTo(-60, 0.01));
    });

    testWidgets('when the strip is shorter than the viewport, it should mount each child only once', (tester) async {
      await tester.pumpWidget(_horizontalMarquee());
      await tester.pump(const Duration(seconds: 3));

      expect(
        (
          find.byKey(const ValueKey('first')).evaluate().length,
          find.byKey(const ValueKey('second')).evaluate().length,
        ),
        (1, 1),
      );
    });

    testWidgets('when configuration changes, it should preserve keyed child state', (tester) async {
      late StateSetter rebuild;
      var direction = MarqueeDirection.right;
      var initializations = 0;
      final children = <Widget>[
        _InitializationCounter(
          key: const ValueKey('first'),
          onInit: () => initializations += 1,
        ),
        _InitializationCounter(
          key: const ValueKey('second'),
          onInit: () => initializations += 1,
        ),
      ];
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _horizontalMarquee(
              direction: direction,
              children: children,
            );
          },
        ),
      );
      rebuild(() => direction = MarqueeDirection.left);
      await tester.pump();

      expect(initializations, 2);
    });

    testWidgets('when the source list grows, it should mount every new source child', (tester) async {
      late StateSetter rebuild;
      var children = <Widget>[
        _child(const ValueKey('first'), width: 20, height: 20),
        _child(const ValueKey('second'), width: 30, height: 30),
      ];
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _testApp(
              disableAnimations: true,
              child: SizedBox(
                width: 20,
                child: Marquee(spacing: 10, children: children),
              ),
            );
          },
        ),
      );
      await tester.pump();
      rebuild(() {
        children = <Widget>[
          ...children,
          _child(const ValueKey('third'), width: 20, height: 20),
          _child(const ValueKey('fourth'), width: 20, height: 20),
          _child(const ValueKey('fifth'), width: 20, height: 20),
        ];
      });
      await tester.pump();

      expect(find.byKey(const ValueKey('fifth')), findsWidgets);
    });

    testWidgets('when text direction changes, it should preserve the physical movement direction', (tester) async {
      await tester.pumpWidget(
        _testApp(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            width: 200,
            child: Marquee(
              direction: MarqueeDirection.right,
              infinity: false,
              spacing: 10,
              children: <Widget>[
                _child(const ValueKey('first'), width: 20, height: 20),
                _child(const ValueKey('second'), width: 30, height: 30),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.getTopLeft(find.byKey(const ValueKey('first'))).dx, closeTo(5, 0.01));
    });

    testWidgets('when tickers are disabled, it should preserve the current position', (tester) async {
      late StateSetter rebuild;
      var tickersEnabled = true;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return _horizontalMarquee(tickersEnabled: tickersEnabled);
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      rebuild(() => tickersEnabled = false);
      await tester.pump();
      final pausedPosition = tester.getTopLeft(find.byKey(const ValueKey('first'))).dx;
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.getTopLeft(find.byKey(const ValueKey('first'))).dx, pausedPosition);
    });

    testWidgets('when reduced motion is requested, it should keep the strip static at the origin', (tester) async {
      await tester.pumpWidget(_horizontalMarquee(disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.getTopLeft(find.byKey(const ValueKey('first'))), Offset.zero);
    });
  });

  group('Marquee interaction and semantics', () {
    testWidgets('when interactive is false, it should ignore child taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _horizontalMarquee(
          disableAnimations: true,
          children: <Widget>[
            _child(
              const ValueKey('first'),
              width: 20,
              height: 20,
              onTap: () => taps += 1,
            ),
            _child(const ValueKey('second'), width: 30, height: 30),
          ],
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('first')),
        warnIfMissed: false,
      );

      expect(taps, 0);
    });

    testWidgets('when interactive is true, it should translate child hit testing', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _horizontalMarquee(
          interactive: true,
          infinity: true,
          children: <Widget>[
            _child(
              const ValueKey('first'),
              width: 20,
              height: 20,
              onTap: () => taps += 1,
            ),
            _child(const ValueKey('second'), width: 30, height: 30),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const ValueKey('first')).at(2));

      expect(taps, 1);
    });

    testWidgets('when interaction is disabled, it should retain child semantics', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _horizontalMarquee(
          disableAnimations: true,
          infinity: true,
          children: <Widget>[
            _child(
              const ValueKey('first'),
              width: 20,
              height: 20,
              semanticsLabel: 'First item',
            ),
            _child(const ValueKey('second'), width: 30, height: 30),
          ],
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('First item'), findsOneWidget);
      semantics.dispose();
    });
  });
}
