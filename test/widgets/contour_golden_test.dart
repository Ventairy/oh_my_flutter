import 'dart:io';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'contour/contour_test_harness.dart';
import 'contour/contour_test_painter.dart';

Future<void> main() async {
  setUpAll(() async {
    final loader = FontLoader('ContourTestInter')
      ..addFont(File('test/fixtures/fonts/inter.ttf').readAsBytes().then(ByteData.sublistView));
    await loader.load();
    await (FontLoader('ContourTestCursive')..addFont(
          File('test/fixtures/fonts/momo_signature/momo_signature.ttf').readAsBytes().then(ByteData.sublistView),
        ))
        .load();
  });
  for (final glyph in ['C', 'O', 'f']) {
    for (final amount in [.5, 1.5, 3.4]) {
      testWidgets('when cursive $glyph expands by $amount, it should closely match the native glyph stroke', (
        tester,
      ) async {
        final harness = ContourTestHarness();
        const style = TextStyle(fontFamily: 'ContourTestCursive', fontSize: 56, height: 1, color: Colors.red);
        await harness.mount(
          tester,
          pixelRatio: 3,
          amount: amount,
          child: Text(glyph, style: style),
        );
        final actual = await harness.pixels(tester, pixelRatio: 4);
        await harness.mount(
          tester,
          color: Colors.transparent,
          pixelRatio: 3,
          child: Stack(
            children: [
              Text(
                glyph,
                style: style.copyWith(
                  foreground: Paint()
                    ..color = Colors.white
                    ..style = PaintingStyle.stroke
                    ..strokeJoin = StrokeJoin.round
                    ..strokeWidth = amount * 2,
                ),
              ),
              Text(glyph, style: style),
            ],
          ),
        );
        final reference = await harness.pixels(tester, pixelRatio: 4);
        expect(ContourTestHarness.countDistantEdges(actual, reference), 0);
      });
    }
  }

  final config = AlchemistConfig.current();
  await AlchemistConfig.runWithConfig(
    config: config.copyWith(ciGoldensConfig: config.ciGoldensConfig.copyWith(obscureText: false, renderShadows: true)),
    run: () => goldenTest(
      'when outlining text and artwork, it should expand every edge and preserve transparent centers',
      fileName: 'contour',
      constraints: const BoxConstraints.tightFor(width: 640, height: 320),
      builder: () => const Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: Color(0xFFF5F5F5),
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Contour(
                      color: Colors.white,
                      amount: 8,
                      shadows: [Shadow(color: Color(0x33000000), offset: Offset(0, 8), blurRadius: 10)],
                      child: Icon(Icons.favorite, size: 64, color: Color(0xFFFF4A4B)),
                    ),
                    Contour(
                      color: Colors.white,
                      amount: 6,
                      shadows: [Shadow(color: Color(0x33000000), offset: Offset(0, 8), blurRadius: 10)],
                      child: Text(
                        'Armando?',
                        style: TextStyle(
                          fontFamily: 'ContourTestInter',
                          fontSize: 40,
                          color: Color(0xFF36ADEB),
                        ),
                      ),
                    ),
                  ],
                ),
                Contour(
                  color: Color(0xFF252630),
                  amount: 1,
                  child: Text(
                    'Com carinho',
                    style: TextStyle(fontFamily: 'ContourTestCursive', fontSize: 32, color: Color(0xFF8050E8)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Contour(
                      color: Colors.yellow,
                      amount: 5,
                      child: CustomPaint(size: Size.square(48), painter: ContourTestPainter()),
                    ),
                    Contour(
                      color: Colors.white,
                      amount: 5,
                      child: CustomPaint(size: Size.square(48), painter: ContourTestPainter(circle: true)),
                    ),
                    Contour(
                      color: Colors.white,
                      amount: 1,
                      child: CustomPaint(size: Size.square(48), painter: ContourTestPainter(fringe: true)),
                    ),
                    Contour(
                      color: Colors.white,
                      amount: 3,
                      child: CustomPaint(size: Size.square(48), painter: ContourTestPainter(open: true)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      whilePerforming: (tester) async {
        await ContourTestHarness.settle(tester);
        return () async {};
      },
    ),
  );
}
