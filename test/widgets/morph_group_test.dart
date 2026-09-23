import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import '../fixtures/morph_paint_probe/morph_paint_probe.dart';

part 'morph_group/_conditional_watched_group_flight_delegate.dart';
part 'morph_group/_group_flight_delegate.dart';
part 'morph_group/_group_flight_harness.dart';
part 'morph_group/_watched_group_flight_delegate.dart';
part 'morph_group/_watched_group_flight_harness.dart';

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

  Future<Rect?> colorBounds(
    WidgetTester tester, {
    required Finder boundary,
    required Color color,
  }) async {
    final renderBoundary = tester.renderObject<RenderRepaintBoundary>(boundary);
    final image = await tester.runAsync(renderBoundary.toImage);
    final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    int? left;
    int? top;
    int? right;
    int? bottom;
    final rgba = bytes!.buffer.asUint8List();
    final argb = color.toARGB32();
    final red = (argb >> 16) & 0xff;
    final green = (argb >> 8) & 0xff;
    final blue = argb & 0xff;
    final alpha = (argb >> 24) & 0xff;
    for (var y = 0; y < image!.height; y += 1) {
      for (var x = 0; x < image.width; x += 1) {
        final offset = (y * image.width + x) * 4;
        if ((rgba[offset] - red).abs() > 32 ||
            (rgba[offset + 1] - green).abs() > 32 ||
            (rgba[offset + 2] - blue).abs() > 32 ||
            (rgba[offset + 3] - alpha).abs() > 32) {
          continue;
        }
        left = left == null ? x : math.min(left, x);
        top = top == null ? y : math.min(top, y);
        right = right == null ? x : math.max(right, x);
        bottom = bottom == null ? y : math.max(bottom, y);
      }
    }
    image.dispose();
    if (left == null) return null;
    return Rect.fromLTRB(
      left.toDouble(),
      top!.toDouble(),
      (right! + 1).toDouble(),
      (bottom! + 1).toDouble(),
    );
  }

  testWidgets(
    'when a watched grouped destination changes coordinate frame, '
    'it should keep stable content visible and hand off the footer without a jump',
    (tester) async {
      final images = <ui.Image>{};
      final previousOnCreate = ui.Image.onCreate;
      final previousOnDispose = ui.Image.onDispose;
      ui.Image.onCreate = (image) {
        previousOnCreate?.call(image);
        images.add(image);
      };
      ui.Image.onDispose = (image) {
        previousOnDispose?.call(image);
        images.remove(image);
      };
      addTearDown(() {
        ui.Image.onCreate = previousOnCreate;
        ui.Image.onDispose = previousOnDispose;
      });
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey<_WatchedGroupFlightHarnessState>();
      await tester.pumpWidget(_WatchedGroupFlightHarness(key: key));
      await tester.pumpAndSettle();

      key.currentState!.showDestination();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final capturesBeforeResize = key.currentState!.capturedInsets.length;
      key.currentState!.resizeDestination();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 280));

      final flightTitle = await colorBounds(
        tester,
        boundary: find.byKey(_WatchedGroupFlightHarness.frameKey),
        color: _WatchedGroupFlightHarness.titleColor,
      );
      final flightFooter = await colorBounds(
        tester,
        boundary: find.byKey(_WatchedGroupFlightHarness.frameKey),
        color: _WatchedGroupFlightHarness.footerColor,
      );

      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump();
      final settledTitle = await colorBounds(
        tester,
        boundary: find.byKey(_WatchedGroupFlightHarness.frameKey),
        color: _WatchedGroupFlightHarness.titleColor,
      );
      final settledFooter = await colorBounds(
        tester,
        boundary: find.byKey(_WatchedGroupFlightHarness.frameKey),
        color: _WatchedGroupFlightHarness.footerColor,
      );
      await tester.pump();
      await tester.pump();

      expect(flightTitle, isNotNull);
      expect(settledTitle, isNotNull);
      expect(flightFooter, isNotNull);
      expect(settledFooter, isNotNull);
      expect((flightFooter!.top - settledFooter!.top).abs(), lessThanOrEqualTo(2));
      expect(key.currentState!.capturedInsets.last, 40);
      expect(key.currentState!.capturedInsets.length, capturesBeforeResize + 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(images, isEmpty);
    },
  );

  testWidgets(
    'when a watched grouped destination repaints while hidden, '
    'it should publish capture-ready endpoints before handoff',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey<_WatchedGroupFlightHarnessState>();
      await tester.pumpWidget(_WatchedGroupFlightHarness(key: key));
      await tester.pumpAndSettle();

      key.currentState!.showDestinationWithAnimatedInset();
      await tester.pump();
      await tester.pump();
      for (var elapsed = 0; elapsed < 600; elapsed += 16) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(
        key.currentState!.builtDestinationInsets,
        contains(predicate<double>((inset) => inset > 0 && inset < 40)),
      );
      await tester.pumpAndSettle();
      expect(key.currentState!.builtDestinationInsets.last, closeTo(40, .01));
    },
  );

  testWidgets(
    'when a watched destination adds a declared group, it should paint before capture',
    (tester) async {
      final target = MorphTarget(
        tag: 'conditional-watched-group',
        duration: const Duration(seconds: 1),
        curve: Curves.linear,
        watchDestination: true,
      );
      final sourceGroup = GroupLink();
      final destinationGroup = GroupLink();
      final events = <String>[];
      var destination = false;
      var destinationHasGroup = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [MorphNavigatorObserver()],
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                final group = destination ? destinationGroup : sourceGroup;
                final capturesGroup = destination && destinationHasGroup;
                return Align(
                  alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
                  child: Morph(
                    key: ValueKey(destination),
                    targets: [target],
                    flightConfig: .custom(
                      _ConditionalWatchedGroupFlightDelegate(
                        group: group,
                        capturesGroup: capturesGroup,
                        onCapture: () => events.add('capture'),
                      ),
                    ),
                    child: SizedBox.square(
                      dimension: destination ? 120 : 80,
                      child: capturesGroup
                          ? Group(
                              link: group,
                              child: MorphPaintProbe(
                                onPaint: () => events.add('paint'),
                                child: const ColoredBox(color: Colors.blue),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      update(() => destination = true);
      await tester.pump();
      await tester.pump();
      events.clear();
      update(() => destinationHasGroup = true);
      await tester.pump();
      await tester.pump();

      expect(events, containsAll(<String>['paint', 'capture']));
      expect(events.indexOf('paint'), lessThan(events.indexOf('capture')));
    },
  );

  testWidgets('when an incoming group first appears, it should hide external semantics before capture', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final key = GlobalKey<_GroupFlightHarnessState>();
      await tester.pumpWidget(_GroupFlightHarness(key: key));
      await tester.pumpAndSettle();
      key.currentState!.show(expanded: true);
      await tester.pump();
      expect(activeLabelCount(tester, 'destination attachment'), 0);
      await tester.pumpAndSettle();
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('when an incoming group first appears, it should keep external content out of the first frame', (
    tester,
  ) async {
    final key = GlobalKey<_GroupFlightHarnessState>();
    await tester.pumpWidget(_GroupFlightHarness(key: key));
    await tester.pumpAndSettle();
    key.currentState!.show(expanded: true);
    late ui.Image frame;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      frame = (key.currentState!._captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary)
          .toImageSync();
    });
    await tester.pump();
    final bytes = await tester.runAsync(() => frame.toByteData(format: ui.ImageByteFormat.rawRgba));
    final offset = (35 * frame.width + 215) * 4;
    final pixel = bytes!.buffer.asUint8List().sublist(offset, offset + 4);
    frame.dispose();
    expect(pixel, [0, 0, 0, 0]);
    await tester.pumpAndSettle();
  });

  testWidgets('when an incoming group is unmatched, it should restore external semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final key = GlobalKey<_GroupFlightHarnessState>();
      await tester.pumpWidget(_GroupFlightHarness(key: key, reducedMotion: true));
      await tester.pumpAndSettle();
      key.currentState!.show(expanded: true);
      await tester.pumpAndSettle();
      expect(activeLabelCount(tester, 'destination attachment'), 1);
    } finally {
      semantics.dispose();
    }
  });

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
        if (!reduced) expect(tester.takeException(), isA<FlutterError>());
        expect(snapshots, findsNothing);
        await tester.pumpAndSettle();
      },
    );
  }
}
