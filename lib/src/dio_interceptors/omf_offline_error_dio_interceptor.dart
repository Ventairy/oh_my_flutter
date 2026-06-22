import 'package:dio/dio.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:meta/meta.dart';

import '../exceptions/omf_offline_connection_dio_exception.dart';

/// A [Interceptor] that wraps connection-type [DioException]s into a
/// [DioException] whose [DioException.error] is an [OmfOfflineConnectionDioException]
/// whenever a real connectivity check confirms the device is offline.
///
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(OfflineErrorDioInterceptor());
///
/// try {
///   await dio.get('/jobs');
/// } on DioException catch (e) {
///   if (e.error is OfflineConnectionException) {
///     // device is offline
///   }
/// }
/// ```
class OmfOfflineErrorDioInterceptor extends Interceptor {
  /// Creates an [OmfOfflineErrorDioInterceptor] that probes real connectivity
  factory OmfOfflineErrorDioInterceptor() {
    return OmfOfflineErrorDioInterceptor._(InternetConnection.createInstance());
  }

  const OmfOfflineErrorDioInterceptor._(this._internetConnection);

  /// Creates an [OmfOfflineErrorDioInterceptor] with a controllable
  /// [internetConnection] for testing.
  @visibleForTesting
  factory OmfOfflineErrorDioInterceptor.test({required InternetConnection internetConnection}) {
    return OmfOfflineErrorDioInterceptor._(internetConnection);
  }

  final InternetConnection _internetConnection;

  static const _checkTimeout = Duration(seconds: 5);

  /// Releases the [InternetConnection] instance held by this interceptor.
  Future<void> dispose() async {
    await _internetConnection.dispose();
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!_shouldCheckConnectivity(err)) {
      handler.next(err);
      return;
    }

    _internetConnection.hasInternetAccess
        .timeout(_checkTimeout)
        .then((online) {
          if (online) {
            handler.next(err);
          } else {
            handler.next(_wrapWithOfflineException(err));
          }
        })
        .catchError((_) {
          handler.next(_wrapWithOfflineException(err));
        });
  }

  /// Returns `true` when the error type could indicate a connection issue.
  ///
  /// Every [DioExceptionType] value is listed explicitly with no wildcard so
  /// that a new type added by Dio forces a compile error here, preventing
  /// silent misclassification.
  bool _shouldCheckConnectivity(DioException err) {
    return switch (err.type) {
      DioExceptionType.badCertificate => false,
      DioExceptionType.badResponse => true,
      DioExceptionType.cancel => false,
      DioExceptionType.connectionError => true,
      DioExceptionType.connectionTimeout => true,
      DioExceptionType.receiveTimeout => true,
      DioExceptionType.sendTimeout => true,
      DioExceptionType.unknown => true,
    };
  }

  DioException _wrapWithOfflineException(DioException err) {
    return DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: OmfOfflineConnectionDioException(
        message: 'No internet connection available to complete the request.',
        cause: err,
      ),
    );
  }
}
