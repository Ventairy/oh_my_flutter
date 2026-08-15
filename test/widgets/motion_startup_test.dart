import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('MotionStartup', () {
    test('when values are read, it should expose every startup behavior', () {
      expect(
        MotionStartup.values,
        <MotionStartup>[
          MotionStartup.play,
          MotionStartup.hold,
          MotionStartup.skip,
        ],
      );
    });
  });
}
