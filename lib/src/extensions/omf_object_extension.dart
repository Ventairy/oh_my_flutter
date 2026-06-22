import 'package:dio/dio.dart';

import '../exceptions/omf_offline_connection_dio_exception.dart';

/// Shared helpers for [Object].
extension ObjectExtension on Object? {
  /// Returns `true` when this is a [DioException] whose [DioException.error]
  /// carries an [OmfOfflineConnectionDioException].
  bool get isOmfOfflineConnectionDioException {
    final self = this;
    return self is DioException && self.error is OmfOfflineConnectionDioException;
  }
}
