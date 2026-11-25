import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'snap_list_test.dart' show SnapListTestHost;

void main() {
  for (final milliseconds in [120, 480]) {
    testWidgets('when removal lasts ${milliseconds}ms, it should reveal the successor on the same timeline', (
      tester,
    ) async {
      final items = ValueNotifier(['a', 'b', 'c']);
      addTearDown(items.dispose);
      late Animation<double> progress;
      await tester.pumpWidget(
        SnapListTestHost.app(
          ValueListenableBuilder(
            valueListenable: items,
            builder: (_, values, _) => SnapList.builder(
              itemCount: values.length,
              itemKeyBuilder: (i) => ValueKey(values[i]),
              itemBuilder: (_, i) => Center(child: Text(values[i])),
              removalDuration: Duration(milliseconds: milliseconds),
              removalTransitionBuilder: (_, animation, child) {
                progress = animation;
                return FadeTransition(opacity: animation.drive(Tween<double>(begin: 1, end: 0)), child: child);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      items.value = ['b', 'c'];
      await tester.pump();
      await tester.pump();
      await tester.pump(Duration(milliseconds: milliseconds ~/ 2));
      final halfway = (
        progress.value,
        find.text('a').evaluate().length,
        find.text('b').hitTestable().evaluate().length,
      );
      await tester.pumpAndSettle();
      expect((halfway, find.text('a').evaluate().length), ((0.5, 1, 1), 0));
    });
  }

  testWidgets('when two partly visible cards disappear together, it should retain both at their painted positions', (
    tester,
  ) async {
    final items = ValueNotifier(['a', 'b', 'c']);
    addTearDown(items.dispose);
    await tester.pumpWidget(
      SnapListTestHost.app(
        ValueListenableBuilder(
          valueListenable: items,
          builder: (_, values, _) => SnapList.builder(
            itemCount: values.length,
            itemKeyBuilder: (i) => ValueKey(values[i]),
            itemBuilder: (_, i) => Center(child: Text(values[i])),
            removalTransitionBuilder: (_, animation, child) =>
                FadeTransition(opacity: ReverseAnimation(animation), child: child),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(find.byType(SnapList)));
    await gesture.moveBy(const Offset(0, -130));
    await gesture.moveBy(const Offset(0, -60));
    await tester.pump();
    final before = (tester.getCenter(find.text('a')), tester.getCenter(find.text('b')));
    items.value = ['c'];
    await tester.pump();
    final after = (tester.getCenter(find.text('a')), tester.getCenter(find.text('b')));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(after, before);
  });
}
