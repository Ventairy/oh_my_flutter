import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'contour_test_harness.dart';

/// Renders repeated identical artwork in aligned cells for shared-resource checks.
class ContourShadowPoolTestHarness {
  /// The boundary containing every repeated cell.
  final GlobalKey boundary = GlobalKey();

  /// The keys retained for every mounted contour.
  final keys = <GlobalKey>[];

  /// Renders an aligned grid with independently configurable backing styles.
  Future<void> mount(
    WidgetTester tester, {
    int count = 20,
    double amount = 3,
    List<Shadow> shadows = const [Shadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
    double pixelRatio = 1,
    bool settle = true,
    Duration? duration,
    double Function(int)? amountFor,
    List<Shadow> Function(int)? shadowsFor,
    Widget Function(int)? childFor,
    bool Function(int)? showFor,
  }) async {
    while (keys.length < count) {
      keys.add(GlobalKey());
    }
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(devicePixelRatio: pixelRatio),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: boundary,
              child: SizedBox(
                width: 640,
                height: 400,
                child: Wrap(
                  children: List.generate(
                    count,
                    (index) => SizedBox(
                      width: 80,
                      height: 70,
                      child: Center(
                        child: (showFor?.call(index) ?? true)
                            ? Contour(
                                key: keys[index],
                                color: const Color(0xFFFFFFFF),
                                amount: amountFor?.call(index) ?? amount,
                                shadows: shadowsFor?.call(index) ?? shadows,
                                child:
                                    childFor?.call(index) ??
                                    const Text(
                                      'OO',
                                      style: TextStyle(fontFamily: 'Ahem', fontSize: 18, color: Color(0xFFFF0000)),
                                    ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      duration: duration,
    );
    if (settle) await ContourTestHarness.settle(tester);
  }

  /// Reads a contour diagnostic without exposing package implementation types.
  Object? property(String name, [int index = 0]) => keys[index].currentContext!
      .findRenderObject()!
      .toDiagnosticsNode()
      .getProperties()
      .firstWhere((property) => property.name == name)
      .value;

  /// Returns the shared image resource identities used by the mounted grid.
  List<int> resourceIds(int count) => [
    for (var index = 0; index < count; index++) property('shadowResourceId', index)! as int,
  ];

  /// Captures exact RGBA samples for cell-by-cell comparisons.
  Future<Uint8List> pixels(WidgetTester tester) async {
    final render = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await tester.runAsync(render.toImage);
    try {
      final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
      return Uint8List.fromList(data!.buffer.asUint8List());
    } finally {
      image!.dispose();
    }
  }

  /// Counts samples differing from the first identically aligned grid cell.
  int mismatchedCells(Uint8List rgba, int count) {
    var mismatches = 0;
    for (var cell = 1; cell < count; cell++) {
      final left = (cell % 8) * 80;
      final top = (cell ~/ 8) * 70;
      for (var y = 0; y < 70; y++) {
        for (var x = 0; x < 80; x++) {
          for (var channel = 0; channel < 4; channel++) {
            if (rgba[((top + y) * 640 + left + x) * 4 + channel] != rgba[(y * 640 + x) * 4 + channel]) {
              mismatches++;
            }
          }
        }
      }
    }
    return mismatches;
  }
}
