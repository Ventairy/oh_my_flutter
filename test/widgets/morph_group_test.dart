import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

part 'morph_group/_group_flight_delegate.dart';
part 'morph_group/_group_flight_harness.dart';

void main() {
  int activeLabelCount(WidgetTester tester, String label) {
    final root = tester.binding.renderViews.first.owner?.semanticsOwner?.rootSemanticsNode;
    var count = 0;
    void visit(SemanticsNode node) {
      if (node.label == label) count++;
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    if (root != null) visit(root);
    return count;
  }

  final snapshots = find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter.runtimeType.toString() == '_MorphGroupSnapshotPainter',
  );

  testWidgets(
    'when destination layout changes after the frame, it should capture the resolved pixels before flight without watching',
    (tester) async {
      final key = GlobalKey<_GroupFlightHarnessState>();
      await tester.pumpWidget(_GroupFlightHarness(key: key, relayoutDestination: true));
      await tester.pumpAndSettle();
      key.currentState!.show(expanded: true);
      await tester.pump();
      await tester.pump();
      final paint = tester.widget<CustomPaint>(snapshots.last);
      final recorder = ui.PictureRecorder();
      paint.painter!.paint(Canvas(recorder), const Size(100, 100));
      final picture = recorder.endRecording();
      final image = await tester.runAsync(() => picture.toImage(100, 100));
      final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
      final rgba = bytes!.buffer.asUint8List();
      final actual = [
        rgba.sublist((10 * 100 + 50) * 4, (10 * 100 + 50) * 4 + 4),
        rgba.sublist((50 * 100 + 50) * 4, (50 * 100 + 50) * 4 + 4),
      ];
      image!.dispose();
      picture.dispose();
      await tester.pumpAndSettle();
      expect(actual, [
        [0, 0, 0, 0],
        [0, 0, 255, 255],
      ]);
    },
  );

  testWidgets('when an attached title has its own Morph, it should exclude the title from the surface snapshot', (
    tester,
  ) async {
    final key = GlobalKey<_GroupFlightHarnessState>();
    await tester.pumpWidget(_GroupFlightHarness(key: key, nestedMorph: true));
    await tester.pumpAndSettle();
    key.currentState!.show(expanded: true);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final paint = tester.widget<CustomPaint>(snapshots.first);
    final recorder = ui.PictureRecorder();
    paint.painter!.paint(Canvas(recorder), const Size(100, 100));
    final picture = recorder.endRecording();
    final image = await tester.runAsync(() => picture.toImage(100, 100));
    final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
    const offset = (15 * 100 + 15) * 4;
    expect(bytes!.buffer.asUint8List().sublist(offset, offset + 4), [255, 0, 0, 255]);
    image!.dispose();
    picture.dispose();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'when an external attachment flies, it should suppress its original semantics and restore them at landing',
    (tester) async {
      final semantics = tester.ensureSemantics();

      final key = GlobalKey<_GroupFlightHarnessState>();
      await tester.pumpWidget(_GroupFlightHarness(key: key));
      await tester.pumpAndSettle();
      key.currentState!.show(expanded: true);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(activeLabelCount(tester, 'destination attachment'), 0);
      await tester.pumpAndSettle();
      expect(activeLabelCount(tester, 'destination attachment'), 1);
      expect(activeLabelCount(tester, 'source attachment'), 0);
      semantics.dispose();
    },
  );

  testWidgets('when an external attachment flies, it should block original taps until landing', (tester) async {
    final key = GlobalKey<_GroupFlightHarnessState>();
    await tester.pumpWidget(_GroupFlightHarness(key: key));
    await tester.pumpAndSettle();
    key.currentState!.show(expanded: true);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tapAt(const Offset(215, 35));
    expect(key.currentState!.taps, 0);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(215, 35));
    expect(key.currentState!.taps, 1);
  });

  for (final interrupted in [false, true]) {
    testWidgets(
      'when a group flight is ${interrupted ? 'interrupted' : 'settled'} then removed, it should release every captured image',
      (tester) async {
        final images = <ui.Image>{};
        final onCreate = ui.Image.onCreate;
        final onDispose = ui.Image.onDispose;
        ui.Image.onCreate = (image) {
          onCreate?.call(image);
          images.add(image);
        };
        ui.Image.onDispose = (image) {
          onDispose?.call(image);
          images.remove(image);
        };
        addTearDown(() {
          ui.Image.onCreate = onCreate;
          ui.Image.onDispose = onDispose;
        });
        final key = GlobalKey<_GroupFlightHarnessState>();
        await tester.pumpWidget(_GroupFlightHarness(key: key));
        await tester.pumpAndSettle();
        key.currentState!.show(expanded: true);
        await tester.pump();
        await tester.pump();
        if (interrupted) {
          await tester.pump(const Duration(milliseconds: 300));
        } else {
          await tester.pumpAndSettle();
        }
        key.currentState!.show(expanded: false);
        await tester.pump();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(images, isEmpty);
      },
    );
  }

  for (final reduced in [false, true]) {
    testWidgets(
      'when ${reduced ? 'motion is disabled' : 'a group is unavailable'}, it should settle without a snapshot flight',
      (tester) async {
        final key = GlobalKey<_GroupFlightHarnessState>();
        await tester.pumpWidget(_GroupFlightHarness(key: key, reducedMotion: reduced, emptyDestination: !reduced));
        await tester.pumpAndSettle();
        key.currentState!.show(expanded: true);
        await tester.pump();
        await tester.pump();
        expect(snapshots, findsNothing);
        await tester.pumpAndSettle();
      },
    );
  }
}
