import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/transition_preparation/prepared_transition.dart';
import 'package:oh_my_flutter/src/widgets/transition_preparation/transition_preparation_scope.dart';

void main() {
  for (final success in [true, false]) {
    testWidgets('when nested preparations finish with success=$success, it should report readiness exactly once', (
      tester,
    ) async {
      final completions = <void Function(bool)>[];
      final results = <bool>[];
      await tester.pumpWidget(
        PreparedTransition(
          onReady: results.add,
          child: Column(
            children: List.generate(
              2,
              (_) => Padding(
                padding: EdgeInsets.zero,
                child: Builder(
                  builder: (context) {
                    completions.add(TransitionPreparationScope.hold(context)!);
                    return const SizedBox();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      completions.first(true);
      completions.first(true);
      await tester.pump();
      final beforeLast = results.length;
      completions.last(success);
      await tester.pump();
      expect([beforeLast, ...results], [0, success]);
    });
  }
}
