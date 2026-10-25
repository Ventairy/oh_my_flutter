@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/contour/tracing/contour_native_port_session.dart';

void main() {
  test(
    'when the browser checks tracing support, it should avoid native bindings',
    () {
      expect(ContourNativePortSession.isSupported, isFalse);
    },
  );

  test(
    'when the browser requests a session, it should return no native owner',
    () {
      expect(ContourNativePortSession.create(), isNull);
    },
  );
}
