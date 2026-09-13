import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('MorphTarget', () {
    test('when two appearances share a tag, it should keep their identities distinct', () {
      final card = MorphTarget(tag: 'item');
      final details = MorphTarget(tag: 'item');

      expect({card, details}, hasLength(2));
    });

    test('when a target receives a tag, it should preserve its matching identity', () {
      const tag = ('item', 42);

      expect(MorphTarget(tag: tag).tag, tag);
    });

    testWidgets(
      'when two attached Morphs share one target, it should diagnose the duplicate appearance even without an Overlay',
      (tester) async {
        final target = MorphTarget(tag: 'surface');
        await tester.pumpWidget(
          Directionality(
            textDirection: .ltr,
            child: Column(
              children: [
                Morph(target: target, child: const SizedBox.square(dimension: 50)),
                Morph(target: target, child: const SizedBox.square(dimension: 50)),
              ],
            ),
          ),
        );
        expect(tester.takeException().toString(), contains('only one attached Morph'));
      },
    );

    testWidgets('when an appearance is removed, it should allow its target to be attached again', (tester) async {
      final target = MorphTarget(tag: 'surface');
      Widget appearance() => Directionality(
        textDirection: .ltr,
        child: Morph(
          animateChildChanges: true,
          target: target,
          child: const SizedBox.square(dimension: 50),
        ),
      );
      await tester.pumpWidget(appearance());
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(appearance());
      expect(tester.takeException(), isNull);
    });
  });
}
