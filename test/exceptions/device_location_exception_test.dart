import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('DeviceLocationException', () {
    test(
      'when converted to text, it should describe its failure reason',
      () {
        expect(
          const DeviceLocationException(
            DeviceLocationExceptionReason.permissionPermanentlyDenied,
          ).toString(),
          contains('permissionPermanentlyDenied'),
        );
      },
    );

    test(
      'when created with a cause, it should preserve that cause',
      () {
        final cause = Exception('native failure');

        expect(
          DeviceLocationException(
            DeviceLocationExceptionReason.coordinatesUnavailable,
            cause: cause,
          ).cause,
          same(cause),
        );
      },
    );
  });
}
