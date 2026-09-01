import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  test('when directions are enumerated, it should expose every physical edge', () {
    expect(
      InteractiveSwipeDismissDirection.values,
      [
        InteractiveSwipeDismissDirection.down,
        InteractiveSwipeDismissDirection.up,
        InteractiveSwipeDismissDirection.left,
        InteractiveSwipeDismissDirection.right,
      ],
    );
  });
}
