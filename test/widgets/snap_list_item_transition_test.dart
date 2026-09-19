import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'snap_list_test.dart' show SnapListTestHost;

class _Item extends StatefulWidget {
  const new({super.key});

  static Widget _incoming(BuildContext context, Animation<double> progress, bool isReverse, Widget child) =>
      FadeTransition(opacity: isReverse ? const AlwaysStoppedAnimation<double>(1) : progress, child: child);

  static Widget _outgoing(BuildContext context, Animation<double> progress, bool isReverse, Widget child) =>
      ScaleTransition(scale: Tween<double>(begin: 1, end: .9).animate(progress), child: child);

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const SizedBox.expand();
  }
}

void main() {
  for (final lazy in [false, true]) {
    testWidgets('when ${lazy ? 'lazy' : 'eager'} items change transition roles, it should preserve child state', (
      tester,
    ) async {
      final controller = SnapListController();
      final key = GlobalKey<_ItemState>();
      await tester.pumpWidget(
        SnapListTestHost.app(
          lazy
              ? SnapList.builder(
                  controller: controller,
                  itemCount: 5,
                  cacheItemCount: 0,
                  incomingTransitionBuilder: _Item._incoming,
                  outgoingTransitionBuilder: _Item._outgoing,
                  itemBuilder: (_, index) => _Item(key: index == 0 ? key : ValueKey(index)),
                )
              : SnapList(
                  controller: controller,
                  incomingTransitionBuilder: _Item._incoming,
                  outgoingTransitionBuilder: _Item._outgoing,
                  children: List.generate(5, (index) => _Item(key: index == 0 ? key : ValueKey(index))),
                ),
        ),
      );
      await tester.pumpAndSettle();
      final original = key.currentState;
      for (var i = 0; i < 3; i++) {
        final next = controller.next();
        await tester.pumpAndSettle();
        await next;
      }
      for (var i = 0; i < 3; i++) {
        final previous = controller.previous();
        await tester.pumpAndSettle();
        await previous;
      }
      expect(key.currentState, same(original));
    });
  }

  testWidgets('when items append from trailing content, it should animate the first new item in', (tester) async {
    final controller = SnapListController();
    var count = 1;
    late StateSetter update;
    final progress = <int, Animation<double>>{};
    await tester.pumpWidget(
      SnapListTestHost.app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return SnapList.builder(
              controller: controller,
              itemCount: count,
              duration: const Duration(milliseconds: 400),
              itemBuilder: (_, index) => SizedBox.expand(key: ValueKey(index)),
              trailingBuilder: (_) => const SizedBox(height: 100),
              incomingTransitionBuilder: (_, value, isReverse, child) {
                progress[(child.key! as ValueKey<int>).value] = value;
                return FadeTransition(opacity: value, child: child);
              },
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final reveal = controller.next();
    await tester.pumpAndSettle();
    await reveal;
    update(() => count = 3);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final halfway = progress[1]?.value;
    await tester.pumpAndSettle();
    expect((halfway, progress[1]?.value, controller.index), (.625, 1.0, 1));
  });
}
