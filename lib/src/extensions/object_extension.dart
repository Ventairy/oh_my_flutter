import 'package:dio/dio.dart';

import '../exceptions/offline_connection_dio_exception.dart';

/// Utilities for nullable [Object] values.
extension ObjectExtension on Object? {
  /// Returns `true` when this is a [DioException] whose [DioException.error]
  /// carries an [OfflineConnectionDioException].
  ///
  /// Returns `false` for `null`, unrelated exceptions, and [DioException]s
  /// carrying another error value. This getter does not perform a connectivity
  /// check; `OfflineErrorDioInterceptor` creates the recognized error shape.
  bool get isOfflineConnectionDioException {
    final self = this;
    return self is DioException && self.error is OfflineConnectionDioException;
  }
}
