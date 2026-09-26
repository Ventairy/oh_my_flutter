import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'snap_list_test.dart' show SnapListTestHost;

class _TransitionDetailsHost {
  final incoming = <int, SnapListTransitionDetails>{};
  final outgoing = <int, SnapListTransitionDetails>{};
  final incomingOpacity = <int, Animation<double>>{};
  final outgoingOpacity = <int, Animation<double>>{};
  bool Function(SnapListTransitionDetails)? skipEffect;

  Widget _incoming(BuildContext context, Animation<double> animation, SnapListTransitionDetails details, Widget child) {
    final index = (child.key! as ValueKey<int>).value;
    incoming[index] = details;
    final opacity = skipEffect?.call(details) ?? false ? const AlwaysStoppedAnimation<double>(1) : animation;
    incomingOpacity[index] = opacity;
    return FadeTransition(key: child.key, opacity: opacity, child: child);
  }

  Widget _outgoing(BuildContext context, Animation<double> animation, SnapListTransitionDetails details, Widget child) {
    final index = (child.key! as ValueKey<int>).value;
    outgoing[index] = details;
    final opacity = skipEffect?.call(details) ?? false
        ? const AlwaysStoppedAnimation<double>(1)
        : Tween<double>(begin: 1, end: 0).animate(animation);
    outgoingOpacity[index] = opacity;
    return FadeTransition(key: child.key, opacity: opacity, child: child);
  }

  Future<void> mount(WidgetTester tester, {bool lazy = false, int count = 1}) async {
    await tester.pumpWidget(
      SnapListTestHost.app(
        lazy
            ? SnapList.builder(
                clipBehavior: Clip.none,
                itemCount: count,
                itemBuilder: (_, index) => SizedBox.expand(key: ValueKey(index)),
                incomingTransitionBuilder: _incoming,
                outgoingTransitionBuilder: _outgoing,
                trailingBuilder: (_) => const SizedBox(key: ValueKey(-1), height: 100),
              )
            : SnapList(
                clipBehavior: Clip.none,
                incomingTransitionBuilder: _incoming,
                outgoingTransitionBuilder: _outgoing,
                trailingBuilder: (_) => const SizedBox(key: ValueKey(-1), height: 100),
                children: List.generate(count, (index) => SizedBox.expand(key: ValueKey(index))),
              ),
      ),
    );
    await tester.pump();
  }

  Future<void> position(WidgetTester tester, double pixels) async {
    tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(pixels);
    await tester.pump();
  }

  List<(bool, bool, bool)> flags(int index) => [
    for (final details in [incoming[index]!, outgoing[index]!])
      (details.isTrailing, details.involvesTrailing, details.isReverse),
  ];

  (double, double) opacity(int index) => (incomingOpacity[index]!.value, outgoingOpacity[index]!.value);
}

void main() {
  for (final revealing in [false, true]) {
    testWidgets(
      'when leaving the last item with reveal=$revealing toward earlier items, it should apply normal effects without trailer metadata',
      (
        tester,
      ) async {
        final host = _TransitionDetailsHost();
        await host.mount(tester, count: 3);
        await host.position(tester, revealing ? 850 : 800);
        await host.position(tester, 700);
        expect(
          [host.flags(2), host.flags(1), host.opacity(2), host.opacity(1)],
          [
            [(false, false, true), (false, false, true)],
            [(false, false, true), (false, false, true)],
            (1.0, .75),
            (.25, 1.0),
          ],
        );
      },
    );
  }

  for (final lazy in [false, true]) {
    testWidgets('when a trailer reveals and rewinds on lazy=$lazy, it should identify both children unambiguously', (
      tester,
    ) async {
      final host = _TransitionDetailsHost();
      await host.mount(tester, lazy: lazy);
      final samples = [host.flags(0), host.flags(-1)];
      await host.position(tester, 50);
      samples.addAll([host.flags(0), host.flags(-1)]);
      await host.position(tester, 25);
      samples.add(host.flags(0));
      await host.position(tester, 100);
      samples.add(host.flags(0));
      await host.position(tester, 50);
      samples.addAll([host.flags(0), host.flags(-1)]);
      await host.position(tester, 0);
      samples.add(host.flags(0));
      expect(samples, [
        for (final flags in [
          (false, false, false),
          (true, true, false),
          (false, true, false),
          (true, true, false),
          (false, true, false),
          (false, true, false),
          (false, true, true),
          (true, true, true),
          (false, false, false),
        ])
          [flags, flags],
      ]);
    });
  }

  for (final choice in ['trailer', 'last item', 'whole reveal']) {
    testWidgets(
      'when the consumer skips effects on the $choice, it should preserve only those children at full opacity',
      (
        tester,
      ) async {
        final host = _TransitionDetailsHost()
          ..skipEffect = (details) => switch (choice) {
            'trailer' => details.isTrailing,
            'last item' => details.involvesTrailing && !details.isTrailing,
            _ => details.involvesTrailing,
          };
        await host.mount(tester);
        await host.position(tester, 50);
        final arriving = (host.opacity(0), host.opacity(-1));
        await host.position(tester, 100);
        final settled = (host.opacity(0), host.opacity(-1));
        await host.position(tester, 50);
        final returning = (host.opacity(0), host.opacity(-1));
        expect(
          [arriving, settled, returning],
          switch (choice) {
            'trailer' => [((1.0, .5), (1.0, 1.0)), ((1.0, 0.0), (1.0, 1.0)), ((.5, 1.0), (1.0, 1.0))],
            'last item' => [((1.0, 1.0), (.5, 1.0)), ((1.0, 1.0), (1.0, 1.0)), ((1.0, 1.0), (1.0, .5))],
            _ => List.filled(3, ((1.0, 1.0), (1.0, 1.0))),
          },
        );
      },
    );
  }

  testWidgets('when items append during a reveal, it should distinguish the continuing departure from the new item', (
    tester,
  ) async {
    final host = _TransitionDetailsHost();
    await host.mount(tester, lazy: true);
    await host.position(tester, 50);
    await host.mount(tester, lazy: true, count: 2);
    final afterAppend = [host.flags(0), host.flags(1), host.flags(-1)];
    await host.position(tester, 0);
    await host.position(tester, 50);
    expect(
      [afterAppend, host.flags(0), host.flags(1)],
      [
        [
          [(false, true, false), (false, true, false)],
          [(false, false, false), (false, false, false)],
          [(true, true, false), (true, true, false)],
        ],
        [(false, false, false), (false, false, false)],
        [(false, false, false), (false, false, false)],
      ],
    );
  });

  testWidgets('when an empty list receives items, it should keep trailer identity separate from item indices', (
    tester,
  ) async {
    final host = _TransitionDetailsHost();
    await host.mount(tester, count: 0);
    final empty = [host.flags(-1), host.opacity(-1)];
    await host.mount(tester);
    expect(
      [empty, host.flags(0), host.flags(-1)],
      [
        [
          [(true, true, false), (true, true, false)],
          (1.0, 1.0),
        ],
        [(false, false, false), (false, false, false)],
        [(true, true, false), (true, true, false)],
      ],
    );
  });
}
