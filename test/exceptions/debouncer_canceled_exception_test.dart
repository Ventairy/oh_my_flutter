import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  test('when converted to text, it should describe the canceled callback', () {
    expect(
      const DebouncerCanceledException().toString(),
      'The debounced result was canceled.',
    );
  });
}
