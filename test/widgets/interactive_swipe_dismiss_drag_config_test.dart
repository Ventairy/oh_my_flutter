import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('InteractiveSwipeDismissDragConfig', () {
    test('when omitted, it should expose neutral drag defaults', () {
      const config = InteractiveSwipeDismissDragConfig();

      expect(config.freeDrag, isFalse);
      expect(config.sensitivity, 1);
      expect(config.dismissThreshold, 0.5);
    });

    test('when sensitivity is not positive, it should reject configuration', () {
      expect(
        () => InteractiveSwipeDismissDragConfig(sensitivity: 0),
        throwsAssertionError,
      );
    });

    test('when sensitivity is infinite, it should reject configuration', () {
      expect(
        () => InteractiveSwipeDismissDragConfig(
          sensitivity: double.infinity,
        ),
        throwsAssertionError,
      );
    });

    test('when threshold is below zero, it should reject configuration', () {
      expect(
        () => InteractiveSwipeDismissDragConfig(dismissThreshold: -0.01),
        throwsAssertionError,
      );
    });

    test('when threshold is above one, it should reject configuration', () {
      expect(
        () => InteractiveSwipeDismissDragConfig(dismissThreshold: 1.01),
        throwsAssertionError,
      );
    });
  });
}
