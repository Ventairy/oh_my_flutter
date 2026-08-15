import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/morph/morph_benchmark_resting_flow_delegate.dart';

void main() {
  group('MorphBenchmarkRestingFlowDelegate', () {
    testWidgets(
      'when the animation moves the paint transform, '
      'it should keep the unchanged child at one build',
      (tester) async {
        final animation = AnimationController(
          vsync: tester,
          duration: const Duration(milliseconds: 100),
        );
        var childBuilds = 0;
        const childKey = ValueKey<String>('resting-flow-child');

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox.square(
                dimension: 200,
                child: Flow(
                  clipBehavior: Clip.none,
                  delegate: MorphBenchmarkRestingFlowDelegate(animation),
                  children: <Widget>[
                    Builder(
                      builder: (context) {
                        childBuilds += 1;
                        return const ColoredBox(
                          key: childKey,
                          color: Colors.blue,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final start = tester.getTopLeft(find.byKey(childKey));

        final completion = animation.forward();
        await tester.pumpAndSettle();
        await completion;
        final end = tester.getTopLeft(find.byKey(childKey));
        final result = (
          childBuilds: childBuilds,
          movement: end - start,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        animation.dispose();

        expect(
          result,
          (childBuilds: 1, movement: const Offset(0, -80)),
        );
      },
    );

    testWidgets(
      'when the animation is at its start, '
      'it should paint the child forty pixels below the flow origin',
      (tester) async {
        const flowKey = ValueKey<String>('resting-flow-start');
        const childKey = ValueKey<String>('resting-flow-start-child');

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox.square(
                dimension: 200,
                child: Flow(
                  key: flowKey,
                  clipBehavior: Clip.none,
                  delegate: MorphBenchmarkRestingFlowDelegate(
                    const AlwaysStoppedAnimation<double>(0),
                  ),
                  children: const <Widget>[
                    ColoredBox(key: childKey, color: Colors.blue),
                  ],
                ),
              ),
            ),
          ),
        );

        final childTopLeft = tester.getTopLeft(find.byKey(childKey));
        final flowTopLeft = tester.getTopLeft(find.byKey(flowKey));

        expect(childTopLeft - flowTopLeft, const Offset(0, 40));
      },
    );

    testWidgets(
      'when the animation is at its end, '
      'it should paint the child forty pixels above the flow origin',
      (tester) async {
        const flowKey = ValueKey<String>('resting-flow-end');
        const childKey = ValueKey<String>('resting-flow-end-child');

        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox.square(
                dimension: 200,
                child: Flow(
                  key: flowKey,
                  clipBehavior: Clip.none,
                  delegate: MorphBenchmarkRestingFlowDelegate(
                    const AlwaysStoppedAnimation<double>(1),
                  ),
                  children: const <Widget>[
                    ColoredBox(key: childKey, color: Colors.blue),
                  ],
                ),
              ),
            ),
          ),
        );

        final childTopLeft = tester.getTopLeft(find.byKey(childKey));
        final flowTopLeft = tester.getTopLeft(find.byKey(flowKey));

        expect(childTopLeft - flowTopLeft, const Offset(0, -40));
      },
    );
  });
}
