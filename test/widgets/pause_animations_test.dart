import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

Widget _testApp({required Widget child, bool tickersEnabled = true}) {
  return MaterialApp(
    home: TickerMode(
      enabled: tickersEnabled,
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('PauseAnimations', () {
    testWidgets(
      'when paused uses its default, it should mute child ticker callbacks',
      (tester) async {
        var ticks = 0;
        await tester.pumpWidget(
          _testApp(
            child: PauseAnimations(
              child: _TickingChild(onTick: () => ticks += 1),
            ),
          ),
        );
        final ticksBeforeFrame = ticks;
        await tester.pump(const Duration(milliseconds: 16));

        expect(ticks, ticksBeforeFrame);
      },
    );

    testWidgets(
      'when paused is false, it should keep child ticker callbacks enabled',
      (tester) async {
        var ticks = 0;
        await tester.pumpWidget(
          _testApp(
            child: PauseAnimations(
              paused: false,
              child: _TickingChild(onTick: () => ticks += 1),
            ),
          ),
        );
        final ticksBeforeFrame = ticks;
        await tester.pump(const Duration(milliseconds: 16));

        expect(ticks, greaterThan(ticksBeforeFrame));
      },
    );

    testWidgets(
      'when paused changes to false, it should enable child ticker callbacks',
      (tester) async {
        late StateSetter rebuild;
        var paused = true;
        var ticks = 0;
        await tester.pumpWidget(
          _testApp(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return PauseAnimations(
                  paused: paused,
                  child: _TickingChild(onTick: () => ticks += 1),
                );
              },
            ),
          ),
        );
        rebuild(() => paused = false);
        await tester.pump();
        final ticksBeforeFrame = ticks;
        await tester.pump(const Duration(milliseconds: 16));

        expect(ticks, greaterThan(ticksBeforeFrame));
      },
    );

    testWidgets(
      'when paused changes, it should preserve child state',
      (tester) async {
        late StateSetter rebuild;
        var paused = true;
        var initializations = 0;
        await tester.pumpWidget(
          _testApp(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return PauseAnimations(
                  paused: paused,
                  child: _TickingChild(
                    onInit: () => initializations += 1,
                    onTick: () {},
                  ),
                );
              },
            ),
          ),
        );
        rebuild(() => paused = false);
        await tester.pump();

        expect(initializations, 1);
      },
    );
  });

  group('PauseAnimations.temporarily', () {
    testWidgets(
      'when the duration has not elapsed, it should mute child ticker callbacks',
      (tester) async {
        var ticks = 0;
        await tester.pumpWidget(
          _testApp(
            child: PauseAnimations.temporarily(
              duration: const Duration(milliseconds: 100),
              child: _TickingChild(onTick: () => ticks += 1),
            ),
          ),
        );
        final ticksBeforeFrame = ticks;
        await tester.pump(const Duration(milliseconds: 99));

        expect(ticks, ticksBeforeFrame);
      },
    );

    testWidgets(
      'when the duration elapses, it should enable child ticker callbacks',
      (tester) async {
        var ticks = 0;
        await tester.pumpWidget(
          _testApp(
            child: PauseAnimations.temporarily(
              duration: const Duration(milliseconds: 100),
              child: _TickingChild(onTick: () => ticks += 1),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final ticksAfterPause = ticks;
        await tester.pump(const Duration(milliseconds: 16));

        expect(ticks, greaterThan(ticksAfterPause));
      },
    );

    testWidgets(
      'when the duration is zero, it should keep child ticker callbacks enabled',
      (tester) async {
        var ticks = 0;
        await tester.pumpWidget(
          _testApp(
            child: PauseAnimations.temporarily(
              duration: Duration.zero,
              child: _TickingChild(onTick: () => ticks += 1),
            ),
          ),
        );
        final ticksBeforeFrame = ticks;
        await tester.pump(const Duration(milliseconds: 16));

        expect(ticks, greaterThan(ticksBeforeFrame));
      },
    );

    testWidgets(
      'when the duration is negative, it should reject mounting',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const PauseAnimations.temporarily(
              duration: Duration(milliseconds: -1),
              child: SizedBox(),
            ),
          ),
        );

        expect(tester.takeException(), isArgumentError);
      },
    );

    testWidgets(
      'when the duration changes, it should restart the temporary pause',
      (tester) async {
        late StateSetter rebuild;
        var duration = const Duration(milliseconds: 100);
        var ticks = 0;
        await tester.pumpWidget(
          _testApp(
            child: StatefulBuilder(
              builder: (context, setState) {
                rebuild = setState;
                return PauseAnimations.temporarily(
                  duration: duration,
                  child: _TickingChild(onTick: () => ticks += 1),
                );
              },
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
        rebuild(() => duration = const Duration(milliseconds: 120));
        await tester.pump();
        final ticksBeforeFrame = ticks;
        await tester.pump(const Duration(milliseconds: 100));

        expect(ticks, ticksBeforeFrame);
      },
    );

    testWidgets(
      'when an ancestor disables tickers, it should not enable them after the duration',
      (tester) async {
        var ticks = 0;
        await tester.pumpWidget(
          _testApp(
            tickersEnabled: false,
            child: PauseAnimations.temporarily(
              duration: const Duration(milliseconds: 100),
              child: _TickingChild(onTick: () => ticks += 1),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        final ticksAfterPause = ticks;
        await tester.pump(const Duration(milliseconds: 16));

        expect(ticks, ticksAfterPause);
      },
    );

    testWidgets(
      'when disposed during the temporary pause, it should cancel its timer',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            child: const PauseAnimations.temporarily(
              duration: Duration(milliseconds: 100),
              child: SizedBox(),
            ),
          ),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull);
      },
    );
  });
}

class _TickingChild extends StatefulWidget {
  const _TickingChild({required this.onTick, this.onInit});

  final VoidCallback onTick;
  final VoidCallback? onInit;

  @override
  State<_TickingChild> createState() => _TickingChildState();
}

class _TickingChildState extends State<_TickingChild> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    widget.onInit?.call();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..addListener(widget.onTick);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(width: 10, height: 10);
}
