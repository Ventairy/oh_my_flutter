import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour.dart' show ContourProcessorTestHarness;
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';

import 'contour_known_box_test_border_radius.dart';
import 'contour_known_box_test_decoration.dart';

void main() {
  const red = Color(0xffff0000);
  const white = Color(0xffffffff);
  Widget scene(
    GlobalKey root,
    GlobalKey contour,
    BoxDecoration box, {
    double amount = 4,
    bool transformed = false,
    Size size = const Size(50, 40),
    Widget? child,
    bool transparent = false,
    double pixelRatio = 3,
  }) {
    Widget source = SizedBox.fromSize(
      size: size,
      child: DecoratedBox(decoration: box, child: child),
    );
    if (transformed) {
      source = Transform(
        transform: Matrix4.identity()
          ..setEntry(0, 0, -1)
          ..setEntry(0, 1, .2),
        alignment: Alignment.center,
        child: source,
      );
    }
    return MediaQuery(
      data: MediaQueryData(devicePixelRatio: pixelRatio),
      child: Directionality(
        textDirection: transformed ? TextDirection.rtl : TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: root,
            child: SizedBox(
              width: 180,
              height: 150,
              child: Center(
                child: Contour(
                  key: contour,
                  color: transparent ? const Color(0x00000000) : white,
                  amount: amount,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: source,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Object? diagnostic(GlobalKey key, String name) => key.currentContext!
      .findRenderObject()!
      .toDiagnosticsNode()
      .getProperties()
      .firstWhere((p) => p.name == name)
      .value;
  Future<Uint8List> pixels(
    WidgetTester tester,
    GlobalKey root, {
    double pixelRatio = 3,
  }) async {
    final image = await tester.runAsync(
      () => (root.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: pixelRatio),
    );
    try {
      final data = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      return data!.buffer.asUint8List();
    } finally {
      image!.dispose();
    }
  }

  Future<Uint8List> oracle(
    WidgetTester tester,
    GlobalKey root,
    GlobalKey contour,
    BoxDecoration box,
    double amount, {
    required bool transformed,
  }) async {
    final source = tester.renderObject<RenderDecoratedBox>(
      find.byType(DecoratedBox),
    );
    final owner = contour.currentContext!.findRenderObject()! as RenderProxyBox;
    final capture = owner.child!;
    final sourceSize = source.size;
    final pixelRatio = MediaQuery.devicePixelRatioOf(contour.currentContext!);
    final rect = Offset.zero & source.size;
    final path = Path();
    if (box.shape == BoxShape.circle) {
      path.addOval(
        Rect.fromCircle(
          center: rect.center,
          radius: source.size.shortestSide / 2,
        ),
      );
    } else if (box.borderRadius != null) {
      path.addRRect(
        box.borderRadius!.resolve(source.configuration.textDirection).toRRect(rect),
      );
    } else {
      path.addRect(rect);
    }
    final backing = path.transform(source.getTransformTo(capture).storage);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..save()
      ..scale(pixelRatio);
    final origin = owner.localToGlobal(
      Offset.zero,
      ancestor: root.currentContext!.findRenderObject(),
    );
    canvas
      ..save()
      ..translate(origin.dx, origin.dy);
    if (!transformed && box.borderRadius == null) {
      // A single expanded native primitive is the reference for supported
      // boxes. Overpainting fill plus stroke changes edge AA even when the
      // geometric union is identical, so it is a different pixel oracle.
      final sourceOrigin = source.localToGlobal(Offset.zero, ancestor: capture);
      final sourceRect = sourceOrigin & sourceSize;
      if (box.shape == BoxShape.circle) {
        canvas.drawCircle(sourceRect.center, sourceSize.shortestSide / 2 + amount, Paint()..color = white);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(sourceRect, Radius.zero).inflate(amount), Paint()..color = white);
      }
    } else {
      canvas
        ..drawPath(backing, Paint()..color = white)
        ..drawPath(
          backing,
          Paint()
            ..color = white
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = amount * 2,
        );
    }
    canvas
      ..restore()
      ..restore();
    // Preserve native child pixels exactly; the oracle independently draws
    // only the new backing geometry. This avoids changing drawRRect AA by
    // replaying its affine transform through a different canvas stack.
    await tester.pumpWidget(
      scene(
        root,
        contour,
        box,
        amount: amount,
        transformed: transformed,
        size: sourceSize,
        pixelRatio: pixelRatio,
        transparent: true,
      ),
    );
    final nativeChild = await tester.runAsync(
      () => (root.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: pixelRatio),
    );
    canvas.drawImage(nativeChild!, Offset.zero, Paint());
    final picture = recorder.endRecording();
    try {
      final image = await tester.runAsync(
        () => picture.toImage(
          (180 * pixelRatio).ceil(),
          (150 * pixelRatio).ceil(),
        ),
      );
      try {
        final data = await tester.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
        );
        return data!.buffer.asUint8List();
      } finally {
        image!.dispose();
      }
    } finally {
      picture.dispose();
      nativeChild.dispose();
    }
  }

  Future<void> cleanup(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    for (var attempt = 0; attempt < 200; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 1));
      if (!ContourProcessorTestHarness.stopping &&
          !ContourProcessorTestHarness.prepared &&
          ContourWorkBudget.shared.activeBytes == 0) {
        return;
      }
    }
    throw StateError(
      'Contour worker shutdown did not release its work capacity.',
    );
  }

  final shapes = <String, BoxDecoration>{
    'rectangle': const BoxDecoration(color: red),
    'rounded': const BoxDecoration(
      color: red,
      borderRadius: BorderRadiusDirectional.only(
        topStart: Radius.circular(12),
        bottomEnd: Radius.elliptical(7, 14),
      ),
    ),
    'circle': const BoxDecoration(color: red, shape: BoxShape.circle),
  };
  for (final entry in shapes.entries) {
    for (final amount in [.5, 4.0]) {
      for (final transformed in [false, true]) {
        testWidgets(
          'when ${entry.key} amount$amount affine$transformed is opaque leaf, it should paint native first-frame pixels without capture',
          (tester) async {
            final root = GlobalKey();
            final contour = GlobalKey();
            addTearDown(() => cleanup(tester));
            await tester.pumpWidget(
              scene(
                root,
                contour,
                entry.value,
                amount: amount,
                transformed: transformed,
              ),
            );
            final first = (
              diagnostic(contour, 'captureCount'),
              diagnostic(contour, 'declaredPathActive'),
              diagnostic(contour, 'firstPresentationHasContour'),
              diagnostic(contour, 'traceNativeStarts'),
            );
            final actual = await pixels(tester, root);
            final expected = await oracle(
              tester,
              root,
              contour,
              entry.value,
              amount,
              transformed: transformed,
            );
            var changed = 0;
            for (var i = 0; i < actual.length; i++) {
              if (actual[i] != expected[i]) changed++;
            }
            expect((first, changed), ((0, true, true, 0), 0));
          },
        );
      }
    }
  }
  final rejected = <String, (BoxDecoration, Size, Widget?)>{
    'blend clear': (
      const BoxDecoration(color: red, backgroundBlendMode: BlendMode.clear),
      const Size(50, 40),
      null,
    ),
    'radius subclass': (
      const BoxDecoration(color: red, borderRadius: ContourKnownBoxTestBorderRadius()),
      const Size(50, 40),
      null,
    ),
    'translucent': (
      const BoxDecoration(color: Color(0x05ff0000)),
      const Size(50, 40),
      null,
    ),
    'subclass': (const ContourKnownBoxTestDecoration(), const Size(50, 40), null),
    'empty': (const BoxDecoration(color: red), Size.zero, null),
    'tiny': (const BoxDecoration(color: red), const Size(.1, .1), null),
    'thin': (const BoxDecoration(color: red), const Size(.01, 100), null),
    'painted child': (
      const BoxDecoration(color: red),
      const Size(50, 40),
      const ColoredBox(color: Color(0xFF00FF00)),
    ),
    'border': (
      BoxDecoration(color: red, border: Border.all()),
      const Size(50, 40),
      null,
    ),
  };
  for (final entry in rejected.entries) {
    testWidgets(
      'when ${entry.key} is unsupported, it should retain the generic fallback',
      (tester) async {
        final root = GlobalKey();
        final contour = GlobalKey();
        addTearDown(() => cleanup(tester));
        await tester.pumpWidget(
          scene(
            root,
            contour,
            entry.value.$1,
            size: entry.value.$2,
            child: entry.value.$3,
          ),
        );
        expect(diagnostic(contour, 'declaredPathActive'), false);
      },
    );
  }

  const updates = [
    (
      name: 'a rectangle becomes a circle',
      oneFrameGap: true,
      box: BoxDecoration(color: red, shape: BoxShape.circle),
      size: Size(50, 40),
      pixelRatio: 3.0,
    ),
    (
      name: 'a known box changes layout',
      oneFrameGap: false,
      box: BoxDecoration(color: red),
      size: Size(30, 60),
      pixelRatio: 3.0,
    ),
    (
      name: 'device pixel ratio changes from three to four',
      oneFrameGap: false,
      box: BoxDecoration(color: red),
      size: Size(50, 40),
      pixelRatio: 4.0,
    ),
  ];
  for (final update in updates) {
    testWidgets(
      'when ${update.name}, it should ${update.oneFrameGap ? 'hide stale backing then match native pixels on the next frame' : 'match native pixels in the first changed composition'} without capture',
      (tester) async {
        final root = GlobalKey();
        final contour = GlobalKey();
        addTearDown(() => cleanup(tester));
        final starts = ContourProcessorTestHarness.starts;
        await tester.pumpWidget(
          scene(root, contour, const BoxDecoration(color: red)),
        );
        final owner = contour.currentContext!.findRenderObject();
        await tester.pumpWidget(
          scene(
            root,
            contour,
            update.box,
            size: update.size,
            pixelRatio: update.pixelRatio,
          ),
        );
        final first = (
          identical(owner, contour.currentContext!.findRenderObject()),
          diagnostic(contour, 'captureCount'),
          diagnostic(contour, 'declaredPathActive'),
          diagnostic(contour, 'lastMainCompositionHasContour'),
          ContourProcessorTestHarness.starts - starts,
        );
        if (update.oneFrameGap) await tester.pump();
        final nextMainHasContour = diagnostic(
          contour,
          'lastMainCompositionHasContour',
        );
        final actual = await pixels(
          tester,
          root,
          pixelRatio: update.pixelRatio,
        );
        final expected = await oracle(
          tester,
          root,
          contour,
          update.box,
          4,
          transformed: false,
        );
        var different = 0;
        for (var channel = 0; channel < actual.length; channel++) {
          if (actual[channel] != expected[channel]) different++;
        }

        expect(
          (first, nextMainHasContour, different),
          ((true, 0, true, !update.oneFrameGap, 0), true, 0),
        );
      },
    );
  }

  testWidgets(
    'when a known opaque box becomes translucent, it should clear the stale backing in the first changed composition and keep its child visible',
    (tester) async {
      final root = GlobalKey();
      final contour = GlobalKey();
      addTearDown(() => cleanup(tester));
      await tester.pumpWidget(
        scene(root, contour, const BoxDecoration(color: red)),
      );
      final before = (
        diagnostic(contour, 'declaredPathActive'),
        diagnostic(contour, 'lastMainCompositionHasContour'),
      );
      const translucent = BoxDecoration(color: Color(0x05ff0000));
      await tester.pumpWidget(scene(root, contour, translucent));
      final first = (
        diagnostic(contour, 'declaredPathActive'),
        diagnostic(contour, 'lastMainCompositionHasContour'),
      );
      final actual = await pixels(tester, root);
      await tester.pumpWidget(
        scene(root, contour, translucent, transparent: true),
      );
      final expected = await pixels(tester, root);
      var different = 0;
      var visible = 0;
      for (var channel = 0; channel < actual.length; channel++) {
        if (actual[channel] != expected[channel]) different++;
        if (channel % 4 == 3 && actual[channel] > 0) visible++;
      }

      expect(
        (before, first, different, visible > 0),
        ((true, true), (false, false), 0, true),
      );
      await cleanup(tester);
    },
  );
}
