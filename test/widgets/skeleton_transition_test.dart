import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

Widget _scene({
  required bool enabled,
  required SkeletonTransition? transition,
  Key? childKey,
  bool disableAnimations = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(
      body: Center(
        child: RepaintBoundary(
          key: const ValueKey('frame'),
          child: Skeleton(
            enabled: enabled,
            transition: transition,
            style: const SkeletonStyle(color: Colors.blue, shape: RoundedRectangleBorder()),
            semanticsLabel: 'Loading',
            child: Semantics(
              label: 'Content',
              child: SizedBox(
                key: childKey,
                width: 40,
                height: 40,
                child: const ColoredBox(color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

Future<Color> _centerPixel(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('frame')));
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final x = image.width ~/ 2;
      final y = image.height ~/ 2;
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

Widget _crossfade(Widget outgoing, Widget incoming, Animation<double> animation) => Stack(
  children: [
    FadeTransition(opacity: ReverseAnimation(animation), child: outgoing),
    FadeTransition(opacity: animation, child: incoming),
  ],
);

void main() {
  testWidgets('when crossfade reveals content, it should blend both appearances midway', (tester) async {
    const transition = SkeletonTransition.crossfade(duration: Duration(milliseconds: 200));
    await tester.pumpWidget(_scene(enabled: true, transition: transition));
    await tester.pumpWidget(_scene(enabled: false, transition: transition));
    await tester.pump(const Duration(milliseconds: 100));

    final pixel = await _centerPixel(tester);
    expect(pixel.r > 0.1 && pixel.b > 0.1, isTrue);
  });

  testWidgets('when crossfade progresses, it should update the retained layer opacities', (tester) async {
    const transition = SkeletonTransition.crossfade(duration: Duration(milliseconds: 200));
    await tester.pumpWidget(_scene(enabled: true, transition: transition));
    await tester.pumpWidget(_scene(enabled: false, transition: transition));
    await tester.pump(const Duration(milliseconds: 50));
    final early = await _centerPixel(tester);
    await tester.pump(const Duration(milliseconds: 100));
    final late = await _centerPixel(tester);

    expect(late.r > early.r, isTrue);
  });

  testWidgets('when an animated skeleton fades out, it should keep its current effect phase', (tester) async {
    Widget scene({required bool enabled}) => MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: const ValueKey('frame'),
          child: ColoredBox(
            color: Colors.black,
            child: Skeleton(
              enabled: enabled,
              transition: const .crossfade(duration: Duration(milliseconds: 200)),
              style: const SkeletonStyle(
                color: Colors.blue,
                shape: RoundedRectangleBorder(),
                effect: SkeletonFadeEffect(duration: Duration(seconds: 1), opacity: (start: 0.1, end: 1)),
              ),
              child: const SizedBox(width: 40, height: 40, child: ColoredBox(color: Colors.red)),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(scene(enabled: true));
    await tester.pump(const Duration(milliseconds: 500));
    final before = await _centerPixel(tester);
    await tester.pumpWidget(scene(enabled: false));
    final after = await _centerPixel(tester);

    expect(after.b, greaterThanOrEqualTo(before.b - 0.02));
  });

  testWidgets('when crossfade starts loading, it should settle on skeleton paint', (tester) async {
    const transition = SkeletonTransition.crossfade(duration: Duration(milliseconds: 200));
    await tester.pumpWidget(_scene(enabled: false, transition: transition));
    await tester.pumpWidget(_scene(enabled: true, transition: transition));
    await tester.pump(const Duration(milliseconds: 200));

    expect((await _centerPixel(tester)).toARGB32(), Colors.blue.toARGB32());
  });

  testWidgets('when crossfade switches modes, it should keep the child key mounted', (tester) async {
    final childKey = GlobalKey();
    const transition = SkeletonTransition.crossfade();
    await tester.pumpWidget(_scene(enabled: true, transition: transition, childKey: childKey));
    final originalElement = childKey.currentContext;
    await tester.pumpWidget(_scene(enabled: false, transition: transition, childKey: childKey));
    await tester.pumpWidget(_scene(enabled: true, transition: transition, childKey: childKey));

    expect(childKey.currentContext, same(originalElement));
  });

  testWidgets('when crossfade paints layered content, it should render without an exception', (tester) async {
    Widget scene({required bool enabled}) => MaterialApp(
      home: Skeleton(
        enabled: enabled,
        transition: const .crossfade(),
        child: const RepaintBoundary(
          child: Opacity(
            opacity: 0.5,
            child: SizedBox(width: 40, height: 40, child: ColoredBox(color: Colors.red)),
          ),
        ),
      ),
    );

    await tester.pumpWidget(scene(enabled: true));
    await tester.pumpWidget(scene(enabled: false));
    await tester.pump(const Duration(milliseconds: 150));

    expect(tester.takeException(), isNull);
  });

  for (final layer in <({String name, Widget Function(Widget child) wrap})>[
    (name: 'transform', wrap: (child) => Transform.scale(scale: 0.8, child: child)),
    (name: 'clip', wrap: (child) => ClipRRect(borderRadius: BorderRadius.circular(6), child: child)),
  ]) {
    testWidgets('when a nested ${layer.name} layer paints during crossfade, it should retain both appearances', (
      tester,
    ) async {
      Widget scene({required bool enabled}) => MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: const ValueKey('frame'),
            child: ColoredBox(
              color: Colors.black,
              child: Skeleton(
                enabled: enabled,
                transition: const .crossfade(duration: Duration(milliseconds: 200)),
                style: const SkeletonStyle(color: Colors.blue, shape: RoundedRectangleBorder()),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: layer.wrap(const RepaintBoundary(child: ColoredBox(color: Colors.red))),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(scene(enabled: false));
      await tester.pumpWidget(scene(enabled: true));
      await tester.pump(const Duration(milliseconds: 100));
      final toSkeleton = await _centerPixel(tester);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(scene(enabled: false));
      await tester.pump(const Duration(milliseconds: 100));
      final toContent = await _centerPixel(tester);
      await tester.pump(const Duration(milliseconds: 100));
      final settled = await _centerPixel(tester);

      expect(
        (
          toSkeletonRed: toSkeleton.r > 0.15,
          toSkeletonBlue: toSkeleton.b > 0.15,
          toContentRed: toContent.r > 0.15,
          toContentBlue: toContent.b > 0.15,
          settledRed: settled.r > 0.9,
        ),
        (toSkeletonRed: true, toSkeletonBlue: true, toContentRed: true, toContentBlue: true, settledRed: true),
      );
    });
  }

  testWidgets('when crossfade progresses, it should retain unchanged child paint', (tester) async {
    final painter = _CountingPainter();
    Widget scene({required bool enabled}) => MaterialApp(
      home: Skeleton(
        enabled: enabled,
        transition: const .crossfade(duration: Duration(milliseconds: 200)),
        child: CustomPaint(size: const Size(40, 40), painter: painter),
      ),
    );

    await tester.pumpWidget(scene(enabled: true));
    await tester.pumpWidget(scene(enabled: false));
    await tester.pump(const Duration(milliseconds: 16));
    final firstFramePaints = painter.paintCount;
    for (var frame = 0; frame < 5; frame += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(painter.paintCount, firstFramePaints);
  });

  testWidgets('when a parent rebuilds during crossfade, it should retain unchanged child paint', (tester) async {
    final painter = _CountingPainter();
    Widget scene({required bool enabled, required String label}) => MaterialApp(
      home: Column(
        children: [
          Skeleton(
            enabled: enabled,
            transition: const .crossfade(duration: Duration(milliseconds: 200)),
            child: CustomPaint(size: const Size(40, 40), painter: painter),
          ),
          Text(label),
        ],
      ),
    );

    await tester.pumpWidget(scene(enabled: true, label: 'before'));
    await tester.pumpWidget(scene(enabled: false, label: 'before'));
    await tester.pump(const Duration(milliseconds: 16));
    final paintsBeforeRebuild = painter.paintCount;
    await tester.pumpWidget(scene(enabled: false, label: 'after'));

    expect(painter.paintCount, paintsBeforeRebuild);
  });

  testWidgets('when crossfade reverses, it should reuse the retained skeleton paint', (tester) async {
    final painter = _CountingPainter();
    Widget scene({required bool enabled}) => MaterialApp(
      home: Skeleton(
        enabled: enabled,
        transition: const .crossfade(duration: Duration(milliseconds: 200)),
        child: CustomPaint(size: const Size(40, 40), painter: painter),
      ),
    );

    await tester.pumpWidget(scene(enabled: true));
    await tester.pumpWidget(scene(enabled: false));
    await tester.pump(const Duration(milliseconds: 50));
    final forwardPaints = painter.paintCount;
    await tester.pumpWidget(scene(enabled: true));

    expect(painter.paintCount, forwardPaints + 1);
  });

  testWidgets('when incoming content repaints, it should reuse the outgoing skeleton paint', (tester) async {
    final repaint = ValueNotifier<int>(0);
    addTearDown(repaint.dispose);
    final painter = _CountingPainter(repaint: repaint);
    Widget scene({required bool enabled}) => MaterialApp(
      home: Skeleton(
        enabled: enabled,
        transition: const .crossfade(duration: Duration(milliseconds: 200)),
        child: CustomPaint(size: const Size(40, 40), painter: painter),
      ),
    );

    await tester.pumpWidget(scene(enabled: true));
    await tester.pumpWidget(scene(enabled: false));
    await tester.pump(const Duration(milliseconds: 16));
    final paintsAtStart = painter.paintCount;
    for (var frame = 0; frame < 5; frame += 1) {
      repaint.value += 1;
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(painter.paintCount, paintsAtStart + 5);
  });

  testWidgets('when updated content reverses into a skeleton, it should use the current bone geometry', (tester) async {
    final width = ValueNotifier<double>(8);
    addTearDown(width.dispose);
    final painter = _SizingPainter(width);
    Widget scene({required bool enabled}) => MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: const ValueKey('frame'),
          child: ColoredBox(
            color: Colors.black,
            child: Skeleton(
              enabled: enabled,
              transition: const .crossfade(duration: Duration(milliseconds: 200)),
              style: const SkeletonStyle(color: Colors.blue, shape: RoundedRectangleBorder()),
              child: CustomPaint(size: const Size(40, 40), painter: painter),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(scene(enabled: true));
    await tester.pumpWidget(scene(enabled: false));
    await tester.pump(const Duration(milliseconds: 50));
    width.value = 35;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpWidget(scene(enabled: true));
    await tester.pump(const Duration(milliseconds: 200));

    expect((await _centerPixel(tester)).b > 0.5, isTrue);
  });

  testWidgets('when content repaints during crossfade, it should show the new paint', (tester) async {
    final color = ValueNotifier<Color>(Colors.red);
    addTearDown(color.dispose);
    final painter = _ChangingPainter(color);
    Widget scene({required bool enabled}) => MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: const ValueKey('frame'),
          child: Skeleton(
            enabled: enabled,
            transition: const .crossfade(duration: Duration(milliseconds: 200)),
            child: CustomPaint(size: const Size(40, 40), painter: painter),
          ),
        ),
      ),
    );

    await tester.pumpWidget(scene(enabled: true));
    await tester.pumpWidget(scene(enabled: false));
    await tester.pump(const Duration(milliseconds: 50));
    final original = await _centerPixel(tester);
    color.value = Colors.green;
    await tester.pump(const Duration(milliseconds: 16));
    final changed = await _centerPixel(tester);

    expect(changed.toARGB32(), isNot(original.toARGB32()));
  });

  testWidgets('when crossfade settles on content, it should show subsequent child repaints', (tester) async {
    final color = ValueNotifier<Color>(Colors.red);
    addTearDown(color.dispose);
    final painter = _ChangingPainter(color);
    Widget scene({required bool enabled}) => MaterialApp(
      home: Center(
        child: RepaintBoundary(
          key: const ValueKey('frame'),
          child: Skeleton(
            enabled: enabled,
            transition: const .crossfade(duration: Duration(milliseconds: 200)),
            child: CustomPaint(size: const Size(40, 40), painter: painter),
          ),
        ),
      ),
    );

    await tester.pumpWidget(scene(enabled: true));
    await tester.pumpWidget(scene(enabled: false));
    await tester.pump(const Duration(milliseconds: 200));
    color.value = Colors.green;
    await tester.pump();

    expect((await _centerPixel(tester)).toARGB32(), Colors.green.toARGB32());
  });

  testWidgets('when custom reveals content, it should keep the child key mounted', (tester) async {
    final childKey = GlobalKey();
    const transition = SkeletonTransition.custom(
      duration: Duration(milliseconds: 200),
      transitionBuilder: _crossfade,
    );
    await tester.pumpWidget(_scene(enabled: true, transition: transition, childKey: childKey));
    final originalElement = childKey.currentContext;
    await tester.pumpWidget(_scene(enabled: false, transition: transition, childKey: childKey));
    await tester.pump(const Duration(milliseconds: 100));

    expect(childKey.currentContext, same(originalElement));
  });

  testWidgets('when custom reveals content, it should show both appearances midway', (tester) async {
    const transition = SkeletonTransition.custom(
      duration: Duration(milliseconds: 200),
      transitionBuilder: _crossfade,
    );
    await tester.pumpWidget(_scene(enabled: true, transition: transition));
    await tester.pumpWidget(_scene(enabled: false, transition: transition));
    await tester.pump(const Duration(milliseconds: 100));

    final pixel = await _centerPixel(tester);
    expect(pixel.r > 0.1 && pixel.b > 0.1, isTrue);
  });

  testWidgets('when custom follows shimmer, it should capture the outgoing appearance', (tester) async {
    const transition = SkeletonTransition.custom(transitionBuilder: _crossfade);
    Widget scene({required bool enabled}) => MaterialApp(
      home: Skeleton(
        enabled: enabled,
        transition: transition,
        style: const SkeletonStyle(effect: SkeletonShimmerEffect()),
        child: const SizedBox(width: 40, height: 40, child: ColoredBox(color: Colors.red)),
      ),
    );

    await tester.pumpWidget(scene(enabled: true));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pumpWidget(scene(enabled: false));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(RawImage), findsOneWidget);
  });

  testWidgets('when custom reverses midway, it should settle on the new target', (tester) async {
    const transition = SkeletonTransition.custom(
      duration: Duration(milliseconds: 200),
      transitionBuilder: _crossfade,
    );
    await tester.pumpWidget(_scene(enabled: true, transition: transition));
    await tester.pumpWidget(_scene(enabled: false, transition: transition));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(_scene(enabled: true, transition: transition));
    await tester.pump(const Duration(milliseconds: 200));

    expect((await _centerPixel(tester)).toARGB32(), Colors.blue.toARGB32());
  });

  testWidgets('when crossfade reverses midway, it should settle on the new target', (tester) async {
    const transition = SkeletonTransition.crossfade(duration: Duration(milliseconds: 200));
    await tester.pumpWidget(_scene(enabled: true, transition: transition));
    await tester.pumpWidget(_scene(enabled: false, transition: transition));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(_scene(enabled: true, transition: transition));
    await tester.pump(const Duration(milliseconds: 200));

    expect((await _centerPixel(tester)).toARGB32(), Colors.blue.toARGB32());
  });

  testWidgets('when reduced motion is requested, it should reveal content immediately', (tester) async {
    const transition = SkeletonTransition.crossfade();
    await tester.pumpWidget(_scene(enabled: true, transition: transition, disableAnimations: true));
    await tester.pumpWidget(_scene(enabled: false, transition: transition, disableAnimations: true));

    expect((await _centerPixel(tester)).toARGB32(), Colors.red.toARGB32());
  });

  testWidgets('when custom reveals content, it should expose only target semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    const transition = SkeletonTransition.custom(transitionBuilder: _crossfade);
    await tester.pumpWidget(_scene(enabled: true, transition: transition));
    await tester.pumpWidget(_scene(enabled: false, transition: transition));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      (find.bySemanticsLabel('Loading').evaluate().length, find.bySemanticsLabel('Content').evaluate().length),
      (0, 1),
    );
    semantics.dispose();
  });

  testWidgets('when crossfade starts loading, it should block the child immediately', (tester) async {
    var taps = 0;
    Widget scene({required bool enabled}) => MaterialApp(
      home: Skeleton(
        enabled: enabled,
        transition: const .crossfade(),
        child: TextButton(onPressed: () => taps += 1, child: const Text('Action')),
      ),
    );

    await tester.pumpWidget(scene(enabled: false));
    await tester.pumpWidget(scene(enabled: true));
    await tester.tap(find.byType(TextButton), warnIfMissed: false);

    expect(taps, 0);
  });

  testWidgets('when custom reveals content, it should enable the child pointer at zero opacity', (tester) async {
    var taps = 0;
    Widget scene({required bool enabled}) => MaterialApp(
      home: Skeleton(
        enabled: enabled,
        transition: const .custom(transitionBuilder: _crossfade),
        child: TextButton(onPressed: () => taps += 1, child: const Text('Action')),
      ),
    );

    await tester.pumpWidget(scene(enabled: true));
    await tester.pumpWidget(scene(enabled: false));
    await tester.tap(find.byType(TextButton));

    expect(taps, 1);
  });

  testWidgets('when custom duration is zero, it should reveal content immediately', (tester) async {
    const transition = SkeletonTransition.custom(
      duration: Duration.zero,
      transitionBuilder: _crossfade,
    );
    await tester.pumpWidget(_scene(enabled: true, transition: transition));
    await tester.pumpWidget(_scene(enabled: false, transition: transition));

    expect((await _centerPixel(tester)).toARGB32(), Colors.red.toARGB32());
  });

  testWidgets('when transition duration is zero, it should reveal content immediately', (tester) async {
    const transition = SkeletonTransition.crossfade(duration: Duration.zero);
    await tester.pumpWidget(_scene(enabled: true, transition: transition));
    await tester.pumpWidget(_scene(enabled: false, transition: transition));

    expect((await _centerPixel(tester)).toARGB32(), Colors.red.toARGB32());
  });

  testWidgets('when reduced motion starts during crossfade, it should settle immediately', (tester) async {
    const transition = SkeletonTransition.crossfade();
    await tester.pumpWidget(_scene(enabled: true, transition: transition));
    await tester.pumpWidget(_scene(enabled: false, transition: transition));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(_scene(enabled: false, transition: transition, disableAnimations: true));

    expect((await _centerPixel(tester)).toARGB32(), Colors.red.toARGB32());
  });

  testWidgets('when transition is omitted, it should reveal content immediately', (tester) async {
    await tester.pumpWidget(_scene(enabled: true, transition: null));
    await tester.pumpWidget(_scene(enabled: false, transition: null));

    expect((await _centerPixel(tester)).toARGB32(), Colors.red.toARGB32());
  });
}

class _CountingPainter extends CustomPainter {
  new({super.repaint});

  int paintCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paintCount += 1;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ChangingPainter extends CustomPainter {
  new(this.color) : super(repaint: color);

  final ValueNotifier<Color> color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color.value);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SizingPainter extends CustomPainter {
  new(this.width) : super(repaint: width);

  final ValueNotifier<double> width;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, width.value, size.height), Paint()..color = Colors.red);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
