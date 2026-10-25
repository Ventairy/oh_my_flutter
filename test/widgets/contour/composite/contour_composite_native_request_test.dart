@TestOn('vm')
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/composite/contour_composite_native_request.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('when native tile metadata is invalid, it should wait for retirement and release its admission', (
    tester,
  ) async {
    final actual = await tester.runAsync(() async {
      final session = ContourNativePortSession.create()!;
      final cancelled = Completer<void>();
      final output = await ContourCompositeNativeRequest.run(
        rgba: Uint8List(16 * 16 * 4),
        width: 16,
        height: 16,
        tiles: Float64List(25),
        session: session,
        cancelled: cancelled.future,
      );
      await session.close();
      cancelled.complete();
      return {'result': output, 'heldBytes': session.stats['heldBytes'], 'jobs': session.stats['jobs']};
    });
    expect(actual, {'result': null, 'heldBytes': 0, 'jobs': 0});
  }, skip: !ContourNativePortSession.isSupported);
}
