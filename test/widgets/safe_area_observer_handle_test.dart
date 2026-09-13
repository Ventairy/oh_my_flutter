import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'maybe_safe_area_test/snapshot_painting_context.dart';

void main() {
  Widget host(Widget child) => MediaQuery(
    data: const MediaQueryData(size: Size(800, 600), padding: EdgeInsets.only(top: 40)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
  );
  test('when unconnected, it should report unavailable geometry', () {
    final handle = SafeAreaObserverHandle();
    addTearDown(handle.dispose);
    expect(handle.avoidanceInsets, isNull);
  });

  testWidgets('when removed, it should notify unavailable geometry', (tester) async {
    final handle = SafeAreaObserverHandle();
    addTearDown(handle.dispose);
    final values = <EdgeInsets?>[];
    handle.addListener(() => values.add(handle.avoidanceInsets));
    await tester.pumpWidget(host(SafeAreaObserver(handle: handle, child: const SizedBox(width: 100, height: 100))));
    await tester.pumpWidget(const SizedBox());
    expect(values, [const EdgeInsets.only(top: 40), null]);
  });

  testWidgets('when unchanged, it should settle after one notification', (tester) async {
    final handle = SafeAreaObserverHandle();
    addTearDown(handle.dispose);
    var calls = 0;
    handle.addListener(() => calls++);
    await tester.pumpWidget(host(SafeAreaObserver(handle: handle, child: const SizedBox(width: 100, height: 100))));
    await tester.pumpAndSettle();
    await tester.pump();
    expect((calls, tester.binding.hasScheduledFrame), (1, false));
  });

  testWidgets('when retained content moves, it should notify without repainting that content', (tester) async {
    final handle = SafeAreaObserverHandle();
    addTearDown(handle.dispose);
    final values = <EdgeInsets?>[];
    handle.addListener(() => values.add(handle.avoidanceInsets));
    const key = ValueKey('transform');
    await tester.pumpWidget(
      host(
        Transform.translate(
          key: key,
          offset: Offset.zero,
          child: RepaintBoundary(
            child: SafeAreaObserver(handle: handle, child: const SizedBox(width: 100, height: 100)),
          ),
        ),
      ),
    );
    tester.renderObject<RenderTransform>(find.byKey(key)).transform = Matrix4.translationValues(0, 80, 0);
    await tester.pumpAndSettle();
    expect(values, [const EdgeInsets.only(top: 40), EdgeInsets.zero]);
  });

  testWidgets('when replaced, it should disconnect the old handle', (tester) async {
    final first = SafeAreaObserverHandle();
    final second = SafeAreaObserverHandle();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    await tester.pumpWidget(host(SafeAreaObserver(handle: first, child: const SizedBox(width: 100, height: 100))));
    await tester.pumpWidget(host(SafeAreaObserver(handle: second, child: const SizedBox(width: 100, height: 100))));
    expect((first.avoidanceInsets, second.avoidanceInsets), (null, const EdgeInsets.only(top: 40)));
  });
  testWidgets('when disposed with a pending notification, it should remain silent', (tester) async {
    final handle = SafeAreaObserverHandle();
    var calls = 0;
    handle.addListener(() => calls++);
    tester.binding.addPostFrameCallback((_) => handle.dispose());
    await tester.pumpWidget(host(SafeAreaObserver(handle: handle, child: const SizedBox(width: 40, height: 20))));
    expect(calls, 0);
  });

  testWidgets('when a detached snapshot is captured, it should leave live notifications unchanged', (tester) async {
    final handle = SafeAreaObserverHandle();
    addTearDown(handle.dispose);
    var calls = 0;
    handle.addListener(() => calls++);
    await tester.pumpWidget(host(SafeAreaObserver(handle: handle, child: const SizedBox(width: 40, height: 20))));
    final box = tester.renderObject<RenderBox>(find.byType(SafeAreaObserver));
    SnapshotPaintingContext.capture(box, const Offset(150, 230)).dispose();
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('when one handle is attached twice, it should diagnose the contract violation', (tester) async {
    final handle = SafeAreaObserverHandle();
    addTearDown(handle.dispose);
    await tester.pumpWidget(host(SafeAreaObserver(handle: handle, child: const SizedBox(width: 40, height: 20))));
    final second = SafeAreaObserver(handle: handle, child: const SizedBox()).createRenderObject(
      tester.element(find.byType(SafeAreaObserver)),
    );
    try {
      expect(() => second.attach(PipelineOwner()), throwsAssertionError);
    } finally {
      if (second.attached) second.detach();
      second.dispose();
    }
  });
}
