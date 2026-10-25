import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'contour_solid_test_painter.dart';
import 'contour_test_harness.dart';

void main() {
  testWidgets('when amount changes continuously, it should defer rebuilding the shadow image until it settles', (
    tester,
  ) async {
    final amount = ValueNotifier<double>(0);
    addTearDown(amount.dispose);
    const key = ValueKey('contour');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ValueListenableBuilder<double>(
            valueListenable: amount,
            builder: (context, value, child) => Contour(
              key: key,
              color: Colors.white,
              amount: value,
              shadows: const [Shadow(blurRadius: 8)],
              child: child!,
            ),
            child: const SizedBox.square(
              dimension: 40,
              child: CustomPaint(painter: ContourSolidTestPainter(color: Colors.red)),
            ),
          ),
        ),
      ),
    );
    await ContourTestHarness.settle(tester);
    for (var frame = 1; frame < 10; frame++) {
      amount.value = frame.toDouble();
      await tester.pump(const Duration(milliseconds: 16));
    }
    final count = tester
        .renderObject<RenderBox>(find.byKey(key))
        .toDiagnosticsNode()
        .getProperties()
        .firstWhere(
          (property) => property.name == 'shadowCacheBuildCount',
        )
        .value;
    await tester.pumpWidget(const SizedBox.shrink());
    expect(count, 1);
  });

  testWidgets('when amount changes between slow frames, it should defer rebuilding the shadow image until it settles', (
    tester,
  ) async {
    final amount = ValueNotifier<double>(0);
    addTearDown(amount.dispose);
    const key = ValueKey('contour');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ValueListenableBuilder<double>(
            valueListenable: amount,
            builder: (context, value, child) => Contour(
              key: key,
              color: Colors.white,
              amount: value,
              shadows: const [Shadow(blurRadius: 8)],
              child: child!,
            ),
            child: const SizedBox.square(
              dimension: 40,
              child: CustomPaint(painter: ContourSolidTestPainter(color: Colors.red)),
            ),
          ),
        ),
      ),
    );
    await ContourTestHarness.settle(tester);
    for (var frame = 1; frame < 10; frame++) {
      amount.value = frame.toDouble();
      await tester.pump(const Duration(milliseconds: 180));
    }
    final count = tester
        .renderObject<RenderBox>(find.byKey(key))
        .toDiagnosticsNode()
        .getProperties()
        .firstWhere(
          (property) => property.name == 'shadowCacheBuildCount',
        )
        .value;
    await tester.pumpWidget(const SizedBox.shrink());
    expect(count, 1);
  });

  testWidgets('when a shadow list contains a sharp shadow, it should preserve vector shadow edges', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      shadows: const [
        Shadow(blurRadius: 8),
        Shadow(offset: Offset(4, 4)),
      ],
      child: const SizedBox.square(
        dimension: 40,
        child: CustomPaint(painter: ContourSolidTestPainter(color: Colors.red)),
      ),
    );
    expect(
      tester
          .renderObject<RenderBox>(find.byKey(harness.backdropKey))
          .toDiagnosticsNode()
          .getProperties()
          .firstWhere(
            (property) => property.name == 'shadowCacheBuildCount',
          )
          .value,
      0,
    );
  });

  testWidgets('when the contour transforms, it should reuse the shadow image', (tester) async {
    final harness = ContourTestHarness();
    const child = SizedBox.square(
      dimension: 40,
      child: CustomPaint(painter: ContourSolidTestPainter(color: Colors.red)),
    );
    const shadows = [Shadow(blurRadius: 8)];
    await harness.mount(tester, shadows: shadows, child: child);
    await harness.mount(tester, scale: 1.5, translation: const Offset(2.5, 1), shadows: shadows, child: child);
    expect(
      tester
          .renderObject<RenderBox>(find.byKey(harness.backdropKey))
          .toDiagnosticsNode()
          .getProperties()
          .firstWhere(
            (property) => property.name == 'shadowCacheBuildCount',
          )
          .value,
      1,
    );
  });

  testWidgets('when a blurred shadow settles, it should cache its rendered pixels', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      shadows: const [Shadow(blurRadius: 8)],
      child: const SizedBox.square(
        dimension: 40,
        child: CustomPaint(painter: ContourSolidTestPainter(color: Colors.red)),
      ),
    );
    expect(
      tester
          .renderObject<RenderBox>(find.byKey(harness.backdropKey))
          .toDiagnosticsNode()
          .getProperties()
          .any(
            (property) => property.name == 'shadowCacheReady' && property.value == true,
          ),
      isTrue,
    );
  });

  testWidgets('when the contour color changes, it should reuse the shadow image', (tester) async {
    final harness = ContourTestHarness();
    const child = SizedBox.square(
      dimension: 40,
      child: CustomPaint(painter: ContourSolidTestPainter(color: Colors.red)),
    );
    const shadows = [Shadow(blurRadius: 8)];
    await harness.mount(tester, shadows: shadows, child: child);
    await harness.mount(tester, color: Colors.blue, shadows: shadows, child: child);
    expect(
      tester
          .renderObject<RenderBox>(find.byKey(harness.backdropKey))
          .toDiagnosticsNode()
          .getProperties()
          .firstWhere(
            (property) => property.name == 'shadowCacheBuildCount',
          )
          .value,
      1,
    );
  });

  testWidgets('when the contour amount changes, it should replace the shadow image', (tester) async {
    final harness = ContourTestHarness();
    const child = SizedBox.square(
      dimension: 40,
      child: CustomPaint(painter: ContourSolidTestPainter(color: Colors.red)),
    );
    const shadows = [Shadow(blurRadius: 8)];
    await harness.mount(tester, shadows: shadows, child: child);
    await harness.mount(tester, amount: 6, shadows: shadows, child: child);
    expect(
      tester
          .renderObject<RenderBox>(find.byKey(harness.backdropKey))
          .toDiagnosticsNode()
          .getProperties()
          .firstWhere(
            (property) => property.name == 'shadowCacheBuildCount',
          )
          .value,
      2,
    );
  });

  testWidgets('when the shadow has no blur, it should avoid allocating a shadow image', (tester) async {
    final harness = ContourTestHarness();
    await harness.mount(
      tester,
      shadows: const [Shadow(offset: Offset(4, 4))],
      child: const SizedBox.square(
        dimension: 40,
        child: CustomPaint(painter: ContourSolidTestPainter(color: Colors.red)),
      ),
    );
    expect(
      tester
          .renderObject<RenderBox>(find.byKey(harness.backdropKey))
          .toDiagnosticsNode()
          .getProperties()
          .any(
            (property) => property.name == 'shadowCacheReady' && property.value == true,
          ),
      isFalse,
    );
  });
}
