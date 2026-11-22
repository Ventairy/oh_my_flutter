import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  testWidgets('when blur changes, it should reuse its child recording', (tester) async {
    var paints = 0;
    await tester.pumpWidget(
      _scene(
        effects: const [_AnimatedBlur()],
        painter: _PaintCounter(() => paints++),
      ),
    );
    await tester.pump();
    final initialPaints = paints;

    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    final imageFilter = tester.layers.whereType<ImageFilterLayer>().single.imageFilter;

    expect((paints, imageFilter), (initialPaints, _filter(3)));
  });

  testWidgets('when a plain Android Skia child fades into blur, it should reuse the sharp recording', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = .android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final compositing = ValueNotifier(false);
    addTearDown(compositing.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Motion.list(
            effects: const [_AnimatedBlur(), FadeInMotionEffect()],
            child: ValueListenableBuilder<bool>(
              valueListenable: compositing,
              builder: (context, needsCompositing, child) => needsCompositing ? RepaintBoundary(child: child) : child!,
              child: const ColoredBox(color: Color(0xFF224488), child: SizedBox(width: 48, height: 32)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final filter = tester.layers.whereType<ImageFilterLayer>().single;
    final picture = (filter.firstChild! as PictureLayer).picture;
    await tester.pump(const Duration(milliseconds: 100));
    final retainedPicture = (filter.firstChild! as PictureLayer).picture;
    final composedFilter = filter.imageFilter;
    compositing.value = true;
    await tester.pump();
    final ordinaryOpacity = (filter.firstChild! as OpacityLayer).alpha;
    compositing.value = false;
    await tester.pump();
    final restoredFilter = filter.imageFilter;
    final restoredPicture = filter.firstChild is PictureLayer;

    expect(
      (retainedPicture, composedFilter, ordinaryOpacity, restoredFilter, restoredPicture),
      (
        picture,
        ui.ImageFilter.compose(
          outer: _filter(4),
          inner: const ui.ColorFilter.mode(Color.fromARGB(170, 0, 0, 0), BlendMode.dstIn),
        ),
        170,
        composedFilter,
        true,
      ),
    );
  }, skip: ui.ImageFilter.isShaderFilterSupported);

  testWidgets('when content changes on a blur tick, it should paint the new content', (tester) async {
    final repaint = ChangeNotifier();
    addTearDown(repaint.dispose);
    var paints = 0;
    await tester.pumpWidget(
      _scene(
        effects: const [_AnimatedBlur()],
        painter: _PaintCounter(() => paints++, repaint: repaint),
      ),
    );
    await tester.pump();
    final initialPaints = paints;

    repaint.notifyListeners();
    await tester.pump(const Duration(milliseconds: 100));
    final imageFilter = tester.layers.whereType<ImageFilterLayer>().single.imageFilter;

    expect((paints, imageFilter), (initialPaints + 1, _filter(3)));
  });

  testWidgets('when blur, opacity and translation change together, it should retain the child recording', (
    tester,
  ) async {
    var paints = 0;
    await tester.pumpWidget(
      _scene(
        effects: const [
          _AnimatedBlur(),
          FadeInMotionEffect(),
          MoveMotionEffect(begin: Offset(10, 0), end: Offset(40, 0)),
        ],
        painter: _PaintCounter(() => paints++),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final initialPaints = paints;

    await tester.pump(const Duration(milliseconds: 100));
    final imageFilter = tester.layers.whereType<ImageFilterLayer>().single;
    final opacity = imageFilter.firstChild! as OpacityLayer;
    final transform = opacity.firstChild! as TransformLayer;

    expect(
      (paints, imageFilter.imageFilter, opacity.alpha, transform.transform!.getTranslation().x),
      (initialPaints, _filter(4), 170, 30),
    );
  });
}

Widget _scene({
  required List<MotionEffect> effects,
  required CustomPainter painter,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(
    child: Motion.list(
      effects: effects,
      child: CustomPaint(size: const Size(50, 30), painter: painter),
    ),
  ),
);

ui.ImageFilter _filter(double sigma) => ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal);

class _AnimatedBlur extends MotionEffect {
  const new();

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.blur(2 + progress * 3);
  }
}

class _PaintCounter extends CustomPainter {
  const new(this.onPaint, {super.repaint});

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xff26384f));
  }

  @override
  bool shouldRepaint(covariant _PaintCounter oldDelegate) => false;
}
