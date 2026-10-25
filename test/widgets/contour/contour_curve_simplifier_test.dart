import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_test_harness.dart';

void main() {
  group('native cursive stroke comparisons', () {
    setUpAll(() async {
      await (FontLoader('ContourSimplifierCursive')..addFont(
            File('test/fixtures/fonts/momo_signature/momo_signature.ttf').readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    });

    for (final glyph in ['S', 'g', 'B', '.']) {
      for (final amount in [.5, 3.4, 8.0]) {
        testWidgets('when simplifying cursive $glyph at amount $amount, it should retain the native stroke shape', (
          tester,
        ) async {
          final harness = ContourTestHarness();
          const style = TextStyle(fontFamily: 'ContourSimplifierCursive', fontSize: 56, height: 1, color: Colors.red);
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
          expect(ContourTestHarness.countDistantEdges(actual, await harness.pixels(tester, pixelRatio: 4)), 0);
        });
      }
    }
  }, skip: kIsWeb ? 'The local font fixture is not bundled into browser tests.' : false);
}
