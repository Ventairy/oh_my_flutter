import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('OfflineConnectionException', () {
    test('when constructed with a message, it should expose the message', () {
      const exception = OfflineConnectionDioException(message: 'No internet connection.');

      expect(exception.message, 'No internet connection.');
    });

    test('when constructed with a cause, it should expose the cause', () {
      final cause = Exception('underlying');
      final exception = OfflineConnectionDioException(message: 'No internet connection.', cause: cause);

      expect(exception.cause, same(cause));
    });

    test('when no cause is provided, it should default to null', () {
      const exception = OfflineConnectionDioException(message: 'No internet connection.');

      expect(exception.cause, isNull);
    });

    test('when converted to a string, it should include the message', () {
      const exception = OfflineConnectionDioException(message: 'No internet connection.');

      expect(exception.toString(), 'OfflineConnectionException: No internet connection.');
    });
  });
}
