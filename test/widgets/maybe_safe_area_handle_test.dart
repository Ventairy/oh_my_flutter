import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'maybe_safe_area_test/snapshot_painting_context.dart';

void main() {
  Widget host(Widget child, {double top = 40}) => MediaQuery(
    data: MediaQueryData(
      size: const Size(800, 600),
      padding: EdgeInsets.only(top: top),
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  );

  test('when unconnected, it should expose no bounds', () {
    final handle = MaybeSafeAreaHandle();
    addTearDown(handle.dispose);
    expect(handle.adjustedBounds, isNull);
  });

  testWidgets('when its child has not painted, it should resolve current bounds', (tester) async {
    final handle = MaybeSafeAreaHandle();
    addTearDown(handle.dispose);
    await tester.pumpWidget(
      host(
        Opacity(
          opacity: 0,
          child: MaybeSafeArea(handle: handle, bottom: false, child: const SizedBox(width: 40, height: 20)),
        ),
      ),
    );
    expect(handle.adjustedBounds, const Rect.fromLTWH(0, 40, 40, 20));
  });

  testWidgets('when geometry stays unchanged, it should settle without repeated notifications', (tester) async {
    final handle = MaybeSafeAreaHandle();
    addTearDown(handle.dispose);
    var calls = 0;
    handle.addListener(() => calls++);
    await tester.pumpWidget(host(MaybeSafeArea(handle: handle, child: const SizedBox(width: 40, height: 20))));
    await tester.pumpAndSettle();
    await tester.pump();
    expect((calls, tester.binding.hasScheduledFrame), (1, false));
  });

  testWidgets('when geometry changes back to zero, it should notify the new bounds', (tester) async {
    final handle = MaybeSafeAreaHandle();
    addTearDown(handle.dispose);
    final values = <double?>[];
    handle.addListener(() => values.add(handle.adjustedBounds?.top));
    final child = MaybeSafeArea(handle: handle, child: const SizedBox(width: 40, height: 20));
    await tester.pumpWidget(host(child));
    await tester.pumpWidget(host(child, top: 0));
    expect(values, [40, 0]);
  });

  testWidgets('when a listener rebuilds, it should notify at a safe time', (tester) async {
    final handle = MaybeSafeAreaHandle();
    addTearDown(handle.dispose);
    var listening = false;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) {
            if (!listening) {
              listening = true;
              handle.addListener(() {
                if (context.mounted) setState(() {});
              });
            }
            return MaybeSafeArea(handle: handle, child: const SizedBox(width: 40, height: 20));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('when the source is removed, it should notify loss of bounds', (tester) async {
    final handle = MaybeSafeAreaHandle();
    addTearDown(handle.dispose);
    final values = <Rect?>[];
    handle.addListener(() => values.add(handle.adjustedBounds));
    await tester.pumpWidget(host(MaybeSafeArea(handle: handle, child: const SizedBox(width: 40, height: 20))));
    await tester.pumpWidget(const SizedBox());
    expect(values, [const Rect.fromLTWH(0, 40, 40, 20), null]);
  });

  testWidgets('when the handle is replaced, it should disconnect the old source', (tester) async {
    final first = MaybeSafeAreaHandle();
    final second = MaybeSafeAreaHandle();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(host(MaybeSafeArea(handle: first, child: const SizedBox(width: 40, height: 20))));
    await tester.pumpWidget(host(MaybeSafeArea(handle: second, child: const SizedBox(width: 40, height: 20))));
    expect((first.adjustedBounds, second.adjustedBounds), (null, const Rect.fromLTWH(0, 40, 40, 20)));
  });

  testWidgets('when disposed with a pending notification, it should remain silent', (tester) async {
    final handle = MaybeSafeAreaHandle();
    var calls = 0;
    handle.addListener(() => calls++);
    tester.binding.addPostFrameCallback((_) => handle.dispose());
    await tester.pumpWidget(host(MaybeSafeArea(handle: handle, child: const SizedBox(width: 40, height: 20))));
    expect(calls, 0);
  });

  testWidgets('when multiple listeners observe geometry, it should notify each once', (tester) async {
    final handle = MaybeSafeAreaHandle();
    addTearDown(handle.dispose);
    final calls = [0, 0];
    handle
      ..addListener(() => calls[0]++)
      ..addListener(() => calls[1]++);
    await tester.pumpWidget(host(MaybeSafeArea(handle: handle, child: const SizedBox(width: 40, height: 20))));
    expect(calls, [1, 1]);
  });

  testWidgets('when a detached snapshot is captured, it should leave live notifications unchanged', (tester) async {
    final handle = MaybeSafeAreaHandle();
    addTearDown(handle.dispose);
    var calls = 0;
    handle.addListener(() => calls++);
    await tester.pumpWidget(host(MaybeSafeArea(handle: handle, child: const SizedBox(width: 40, height: 20))));
    final box = tester.renderObject<RenderBox>(find.byType(MaybeSafeArea));
    SnapshotPaintingContext.capture(box, const Offset(150, 230)).dispose();
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('when scaled by an ancestor, it should report local logical bounds', (tester) async {
    final handle = MaybeSafeAreaHandle();
    addTearDown(handle.dispose);
    await tester.pumpWidget(
      host(
        Transform.scale(
          scale: 2,
          alignment: Alignment.topLeft,
          child: MaybeSafeArea(handle: handle, child: const SizedBox(width: 40, height: 20)),
        ),
      ),
    );
    expect(handle.adjustedBounds, const Rect.fromLTWH(0, 20, 40, 20));
  });

  testWidgets('when one handle is attached twice, it should diagnose the contract violation', (tester) async {
    final handle = MaybeSafeAreaHandle();
    addTearDown(handle.dispose);
    await tester.pumpWidget(host(MaybeSafeArea(handle: handle, child: const SizedBox(width: 40, height: 20))));
    final second = MaybeSafeArea(handle: handle, child: const SizedBox()).createRenderObject(
      tester.element(find.byType(MaybeSafeArea)),
    );
    try {
      expect(() => second.attach(PipelineOwner()), throwsAssertionError);
    } finally {
      if (second.attached) second.detach();
      second.dispose();
    }
  });

  testWidgets('when a handle reattaches, it should report the new source bounds', (tester) async {
    final handle = MaybeSafeAreaHandle();
    addTearDown(handle.dispose);
    final values = <Rect?>[];
    handle.addListener(() => values.add(handle.adjustedBounds));
    await tester.pumpWidget(host(MaybeSafeArea(handle: handle, child: const SizedBox(width: 40, height: 20))));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(host(MaybeSafeArea(handle: handle, child: const SizedBox(width: 60, height: 30))));
    expect(values, [const Rect.fromLTWH(0, 40, 40, 20), null, const Rect.fromLTWH(0, 40, 60, 30)]);
  });

  for (final behavior in MaybeSafeAreaBehavior.values) {
    testWidgets('when $behavior moves under a retained ancestor, it should respect its correction policy', (
      tester,
    ) async {
      final handle = MaybeSafeAreaHandle();
      addTearDown(handle.dispose);
      final child = RepaintBoundary(
        child: MaybeSafeArea(handle: handle, behavior: behavior, child: const SizedBox(width: 40, height: 20)),
      );
      await tester.pumpWidget(host(Transform.translate(offset: const Offset(0, 100), child: child)));
      await tester.pumpWidget(host(Transform.translate(offset: Offset.zero, child: child)));
      expect(handle.adjustedBounds?.top, behavior == MaybeSafeAreaBehavior.live ? 40 : 0);
    });
  }

  testWidgets('when a retained child moves, it should notify without rebuilding the child', (tester) async {
    final handle = MaybeSafeAreaHandle();
    addTearDown(handle.dispose);
    final values = <Rect?>[];
    handle.addListener(() => values.add(handle.adjustedBounds));
    final child = RepaintBoundary(
      child: MaybeSafeArea(handle: handle, bottom: false, child: const SizedBox(width: 40, height: 20)),
    );
    Widget host(double y) => MediaQuery(
      data: const MediaQueryData(size: Size(800, 600), padding: EdgeInsets.only(top: 40)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: Transform.translate(offset: Offset(0, y), child: child),
        ),
      ),
    );
    await tester.pumpWidget(host(100));
    await tester.pumpWidget(host(0));
    expect(values.map((value) => value?.top), [0, 40]);
  });
}
