import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  testWidgets('when a settled list resizes through keyboard geometry, it should keep its selected card opaque', (
    tester,
  ) async {
    final snapController = SnapListController();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final height = ValueNotifier<double>(605);
    addTearDown(height.dispose);
    final incoming = <int, Animation<double>>{};
    final outgoing = <int, Animation<double>>{};
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: ValueListenableBuilder<double>(
            valueListenable: height,
            builder: (_, value, child) => SizedBox(width: 390, height: value, child: child),
            child: SnapList.builder(
              controller: snapController,
              clipBehavior: Clip.none,
              spacing: 10,
              cacheItemCount: 3,
              itemCount: 5,
              incomingTransitionBuilder: (_, progress, reverse, child) {
                incoming[(child.key! as ValueKey<int>).value] = progress;
                return FadeTransition(opacity: progress, child: child);
              },
              outgoingTransitionBuilder: (_, progress, reverse, child) {
                outgoing[(child.key! as ValueKey<int>).value] = progress;
                return FadeTransition(
                  key: child.key,
                  opacity: Tween<double>(begin: 1, end: 0).animate(progress),
                  child: child,
                );
              },
              itemBuilder: (_, index) => SizedBox.expand(key: ValueKey(index)),
            ),
          ),
        ),
      ),
    );
    for (var index = 0; index < 3; index++) {
      final result = snapController.next();
      await tester.pumpAndSettle();
      await result;
    }
    final samples = <Object>[];
    for (final stride in [
      615.0,
      619.2655212624245,
      623.087276662973,
      620.9699400334553,
      619.3750789017506,
      618.1865899232112,
      618.9736889576482,
      616.195902890586,
      616.4665968984616,
      615.4344406688365,
      615.30827670277,
      615.2182469938259,
      615.2628917672787,
      615.255548336779,
      615.0,
    ]) {
      height.value = stride - 10;
      await tester.pump(const Duration(milliseconds: 16));
      final card = tester.getRect(find.byKey(const ValueKey(3)).last);
      final viewport = tester.getRect(find.byType(SnapList));
      final previousFinder = find.byKey(const ValueKey(2), skipOffstage: false);
      final previous = previousFinder.evaluate().isEmpty ? null : tester.getRect(previousFinder.last);
      samples.add((
        snapController.index,
        incoming[3]!.value,
        outgoing[3]!.value,
        (card.top - viewport.top).abs() < 0.001,
        previous == null || previous.bottom <= viewport.top - 9.999,
      ));
    }
    expect(samples, everyElement((3, 1.0, 0.0, true, true)));
    await tester.pumpWidget(const SizedBox());
    snapController.dispose();
  });
}
