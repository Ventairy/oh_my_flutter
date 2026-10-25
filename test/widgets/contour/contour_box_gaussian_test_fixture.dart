import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour.dart';

class ContourBoxGaussianTestFixture {
  new({bool? supported = true})
    : _harness = supported == null ? null : ContourBoxGaussianShadowTestHarness.test(supported: supported) {
    _harness?.install();
  }

  final ContourBoxGaussianShadowTestHarness? _harness;
  final GlobalKey key = GlobalKey();
  final GlobalKey boundaryKey = GlobalKey();

  Widget scene({
    List<Shadow> shadows = const [Shadow(color: Color(0x33000000), blurRadius: 20)],
    BoxDecoration decoration = const BoxDecoration(
      color: Color(0xff33aaee),
      borderRadius: BorderRadius.all(Radius.circular(6)),
    ),
    Size size = const Size(32, 30),
    double amount = 4,
    double pixelRatio = 1,
    Widget? content,
    Matrix4? transform,
  }) {
    final widget =
        content ??
        Contour(
          key: key,
          color: const Color(0xffffffff),
          amount: amount,
          shadows: shadows,
          child: Container(width: size.width, height: size.height, decoration: decoration),
        );
    return MediaQuery(
      data: MediaQueryData(devicePixelRatio: pixelRatio),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 400,
              height: 300,
              child: Center(
                child: transform == null
                    ? widget
                    : Transform(transform: transform, alignment: Alignment.center, child: widget),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<String?, Object?> get values => {
    for (final value in key.currentContext!.findRenderObject()!.toDiagnosticsNode().getProperties())
      value.name: value.value,
  };

  Future<void> finish(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
      await tester.pump(const Duration(milliseconds: 1));
      if (values['firstPresentationHasContour'] == true) return;
    }
  }

  Future<Uint8List> pixels(WidgetTester tester) async {
    final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await tester.runAsync(boundary.toImage);
    final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
    image!.dispose();
    return data!.buffer.asUint8List();
  }

  void dispose() => _harness?.dispose();
}
