import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_test_harness.dart';
import 'contour_test_painter.dart';

void main() {
  testWidgets(
    'when web artwork has many disconnected dots, it should batch its cooperative timer yields',
    (tester) async {
      final harness = ContourTestHarness();
      var zeroDurationTimers = 0;
      await runZoned<Future<void>>(
        () => harness.mount(
          tester,
          amount: .5,
          child: const CustomPaint(size: Size.square(64), painter: ContourTestPainter(dotGrid: true)),
        ),
        zoneSpecification: ZoneSpecification(
          createTimer: (self, parent, zone, duration, callback) {
            if (duration == Duration.zero) zeroDurationTimers++;
            return parent.createTimer(zone, duration, callback);
          },
        ),
      );
      // The 192-pixel capture needs fewer than 40 row-level yields. Batched
      // pixel work fits comfortably below 100; one yield per dot cannot.
      expect(zeroDurationTimers, allOf(greaterThan(0), lessThan(100)));
    },
    skip: !kIsWeb,
  );

  for (final circle in [false, true]) {
    for (final amount in [.5, 1.5, 3.4]) {
      testWidgets(
        'when expanding a ${circle ? "circle" : "box"} by $amount, it should match the native path stroke',
        (tester) async {
          final harness = ContourTestHarness();
          await harness.mount(
            tester,
            pixelRatio: 3,
            amount: amount,
            child: CustomPaint(
              size: const Size.square(40),
              painter: ContourTestPainter(circle: circle),
            ),
          );
          final actual = await harness.pixels(tester, pixelRatio: 4);
          await harness.mount(
            tester,
            pixelRatio: 3,
            color: const Color(0x00000000),
            child: CustomPaint(
              size: const Size.square(40),
              painter: ContourTestPainter(circle: circle, strokeWidth: amount * 2),
            ),
          );
          expect(ContourTestHarness.countDistantEdges(actual, await harness.pixels(tester, pixelRatio: 4)), 0);
        },
      );
    }
  }

  testWidgets('when a curve has a faint antialiasing fringe, it should not turn that fringe into a bump', (
    tester,
  ) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 1,
      child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter(fringe: true)),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 50, 34).last, lessThan(32));
  });

  for (final density in [1.0, 3.0, 4.0]) {
    testWidgets('when emoji-like specks appear at density $density, it should omit their expanded backing', (
      tester,
    ) async {
      final harness = ContourTestHarness();
      await harness.mount(
        tester,
        pixelRatio: density,
        amount: 6,
        child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter(specks: true)),
      );
      expect(ContourTestHarness.pixel(await harness.pixels(tester), 32, 32).last, lessThan(64));
    });
  }

  testWidgets('when a faint fringe is several pixels thick, it should not turn its interior opaque', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 1,
      child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter(fringe: true, fringeWidth: 3)),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 51, 34).last, lessThan(32));
  });

  testWidgets('when separate visible artwork has different opacity, it should contour both components', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 2,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(dimension: 20, child: ColoredBox(color: Color(0xFFFF0000))),
          SizedBox(width: 20),
          SizedBox.square(dimension: 20, child: ColoredBox(color: Color(0x28FF0000))),
        ],
      ),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 80, 50), [255, 255, 255, 255]);
  });

  testWidgets('when a separate region is almost transparent, it should omit its backing', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 2,
      child: const SizedBox.square(dimension: 20, child: ColoredBox(color: Color(0x01FF0000))),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 50, 50).last, 1);
  });

  testWidgets('when an opaque detail is smaller than one logical pixel, it should retain its contour', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 2,
      child: const SizedBox.square(dimension: .5, child: ColoredBox(color: Color(0xFFFF0000))),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 51, 50).last, greaterThan(64));
  });

  testWidgets('when visible translucent artwork touches opaque artwork, it should contour both', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 2,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(dimension: 20, child: ColoredBox(color: Color(0xFFFF0000))),
          SizedBox.square(dimension: 20, child: ColoredBox(color: Color(0x33FF0000))),
        ],
      ),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 60, 50), [255, 204, 204, 255]);
  });

  testWidgets('when a contour scales down, it should preserve a smooth curved edge', (tester) async {
    final harness = ContourTestHarness();
    const scale = .73;
    const radius = 21.5 * scale;
    await harness.mount(
      tester,
      amount: 1.5,
      scale: scale,
      child: const SizedBox.square(
        dimension: 40,
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF0000)),
        ),
      ),
    );
    final contour = await harness.pixels(tester);
    await harness.mount(
      tester,
      color: const Color(0x00000000),
      child: const SizedBox.square(
        dimension: radius * 2,
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF0000)),
        ),
      ),
    );
    final reference = await harness.pixels(tester);
    var error = 0.0;
    for (var y = 0; y < 100; y++) {
      for (var x = 0; x < 100; x++) {
        final distance = math.sqrt(math.pow(x + .5 - 50, 2) + math.pow(y + .5 - 50, 2));
        if ((distance - radius).abs() > 1.5) continue;
        final alpha = (y * 100 + x) * 4 + 3;
        error = math.max(error, (contour[alpha] - reference[alpha]).abs() / 255);
      }
    }
    expect(error, lessThan(.3));
  });

  for (final amount in [.5, 1.5, 3.4]) {
    testWidgets('when a smooth circle expands by $amount, it should retain an accurate curved boundary', (
      tester,
    ) async {
      final harness = ContourTestHarness();
      await harness.mount(
        tester,
        amount: amount,
        child: const SizedBox.square(
          dimension: 40,
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF0000)),
          ),
        ),
      );
      final pixels = await harness.pixels(tester);
      var area = 0.0;
      for (var index = 3; index < pixels.length; index += 4) {
        area += pixels[index] / 255;
      }
      final expectedArea = math.pi * math.pow(20 + amount, 2);
      expect(area, closeTo(expectedArea, expectedArea * .01));
    });
  }

  for (final density in [1.0, 2.0, 3.0]) {
    for (final amount in [2.0, 8.0, 18.0]) {
      testWidgets(
        'when a circle expands by $amount at density $density, it should stay within the expanded circle',
        (tester) async {
          final harness = ContourTestHarness();
          await harness.mount(
            tester,
            pixelRatio: density,
            amount: amount,
            child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter(circle: true)),
          );
          final bytes = await harness.pixels(tester);
          var maximumRadius = 0.0;
          for (var y = 0; y < 100; y++) {
            for (var x = 0; x < 100; x++) {
              if (bytes[(y * 100 + x) * 4 + 3] < 32) continue;
              maximumRadius = math.max(maximumRadius, math.sqrt(math.pow(x + .5 - 50, 2) + math.pow(y + .5 - 50, 2)));
            }
          }
          // Allow one destination pixel for antialiasing and reconstruction.
          expect(maximumRadius, lessThanOrEqualTo(20 + amount + 1));
        },
      );
    }
  }

  testWidgets('when a source has a sharp corner, it should round the expanded corner without a spike', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 6,
      child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter()),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 25, 25).last, lessThan(32));
  });

  testWidgets('when artwork has an acute tip, it should limit amount to the configured distance', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 8,
      child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter(pointed: true)),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 50, 19), [0, 0, 0, 0]);
  });

  testWidgets('when the exterior is curved, it should preserve transparency outside the curve', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 2,
      child: const CustomPaint(size: Size.square(40), painter: ContourTestPainter(circle: true)),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 30, 30), [0, 0, 0, 0]);
  });

  testWidgets('when components are disconnected, it should preserve the gap between them', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(dimension: 20, child: ColoredBox(color: Color(0xFFFF0000))),
          SizedBox(width: 20),
          SizedBox.square(dimension: 20, child: ColoredBox(color: Color(0xFFFF0000))),
        ],
      ),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 50, 50), [0, 0, 0, 0]);
  });

  testWidgets('when components expand into one another, it should join their backing', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 12,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(dimension: 20, child: ColoredBox(color: Color(0xFFFF0000))),
          SizedBox(width: 20),
          SizedBox.square(dimension: 20, child: ColoredBox(color: Color(0xFFFF0000))),
        ],
      ),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 50, 50), [255, 255, 255, 255]);
  });

  testWidgets('when artwork is translucent, it should still generate an opaque expanded contour', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      amount: 6,
      child: const Opacity(
        opacity: .2,
        child: CustomPaint(size: Size.square(40), painter: ContourTestPainter()),
      ),
    );
    expect(ContourTestHarness.pixel(await harness.pixels(tester), 26, 50), [255, 255, 255, 255]);
  });
}
