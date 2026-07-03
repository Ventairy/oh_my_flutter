import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('OmfVelocityExtension', () {
    test('when the velocity moves down faster than the minimum, it should detect a down swipe', () {
      const velocity = Velocity(pixelsPerSecond: Offset(0, 701));

      expect(velocity.isSwipeDown(), isTrue);
    });

    test('when the velocity moves up faster than the minimum, it should detect an up swipe', () {
      const velocity = Velocity(pixelsPerSecond: Offset(0, -701));

      expect(velocity.isSwipeUp(), isTrue);
    });

    test('when the velocity moves left faster than the minimum, it should detect a left swipe', () {
      const velocity = Velocity(pixelsPerSecond: Offset(-701, 0));

      expect(velocity.isSwipeLeft(), isTrue);
    });

    test('when the velocity moves right faster than the minimum, it should detect a right swipe', () {
      const velocity = Velocity(pixelsPerSecond: Offset(701, 0));

      expect(velocity.isSwipeRight(), isTrue);
    });

    test('when the velocity is slower than the minimum, it should not detect a down swipe', () {
      const velocity = Velocity(pixelsPerSecond: Offset(0, 699));

      expect(velocity.isSwipeDown(), isFalse);
    });

    test('when the velocity moves in the opposite direction, it should not detect a down swipe', () {
      const velocity = Velocity(pixelsPerSecond: Offset(0, -701));

      expect(velocity.isSwipeDown(), isFalse);
    });

    test('when the horizontal velocity dominates a diagonal movement, it should not detect a down swipe', () {
      const velocity = Velocity(pixelsPerSecond: Offset(900, 701));

      expect(velocity.isSwipeDown(), isFalse);
    });

    test('when axis dominance is disabled for a diagonal movement, it should detect a down swipe', () {
      const velocity = Velocity(pixelsPerSecond: Offset(900, 701));

      expect(velocity.isSwipeDown(requireVerticalDominance: false), isTrue);
    });

    test('when diagonal velocities are equal with dominance required, it should not detect a down swipe', () {
      const velocity = Velocity(pixelsPerSecond: Offset(701, 701));

      expect(velocity.isSwipeDown(), isFalse);
    });

    test('when diagonal velocities are equal with dominance required, it should not detect a right swipe', () {
      const velocity = Velocity(pixelsPerSecond: Offset(701, 701));

      expect(velocity.isSwipeRight(), isFalse);
    });

    test('when using a custom minimum velocity, it should detect a matching down swipe', () {
      const velocity = Velocity(pixelsPerSecond: Offset(0, 500));

      expect(velocity.isSwipeDown(minVelocity: 500), isTrue);
    });
  });
}
