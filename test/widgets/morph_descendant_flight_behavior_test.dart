import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  test('when snapshot behavior has a notifier, it should still match an unconfigured snapshot', () {
    final changes = ChangeNotifier();
    addTearDown(changes.dispose);

    expect(MorphDescendantFlightBehavior.snapshot(changes: changes), const MorphDescendantFlightBehavior.snapshot());
  });

  test('when flight behaviors differ, it should keep them distinct', () {
    expect(
      {
        const MorphDescendantFlightBehavior.live(),
        const MorphDescendantFlightBehavior.snapshot(),
        const MorphDescendantFlightBehavior.hide(),
      }.length,
      3,
    );
  });
}
