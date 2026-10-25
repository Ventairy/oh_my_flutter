import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter_example/examples/contour_entrance_example.dart';
import 'package:oh_my_flutter_example/examples/contour_entrance_sample.dart';

void main() {
  testWidgets('when replaying entrances, it should mount new sticker instances', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: ContourEntranceExample())),
      ),
    );
    final previousKeys = tester
        .widgetList<ContourEntranceSample>(find.byType(ContourEntranceSample))
        .map((item) => item.key)
        .toList();
    await tester.tap(find.text('Replay entrances'));
    await tester.pump();
    final currentKeys = tester
        .widgetList<ContourEntranceSample>(find.byType(ContourEntranceSample))
        .map((item) => item.key)
        .toList();
    expect(currentKeys.any(previousKeys.contains), isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  });

  testWidgets('when disabling pop, it should demonstrate fade-only entrances', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: ContourEntranceExample())),
      ),
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(
      tester.widgetList<ContourEntranceSample>(find.byType(ContourEntranceSample)).every((sample) => !sample.pop),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  });

  testWidgets('when displayed on a compact screen, it should keep both comparison columns within the viewport', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: ContourEntranceExample())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  });
}
