import 'dart:async';

import 'package:dio/dio.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:meta/meta.dart';

import '../exceptions/offline_connection_dio_exception.dart';

/// A [Interceptor] that wraps connection-type [DioException]s into a
/// [DioException] whose [DioException.error] is an [OfflineConnectionDioException]
/// whenever a real connectivity check confirms the device is offline.
///
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(OfflineErrorDioInterceptor());
///
/// try {
///   await dio.get('/jobs');
/// } on DioException catch (e) {
///   if (e.error is OfflineConnectionDioException) {
///     // device is offline
///   }
/// }
/// ```
///
/// Connection, request timeout, response timeout, response, and unknown errors
/// trigger a real internet-access probe with a five-second timeout. If the
/// probe reports online, the original exception continues unchanged. If it
/// reports offline, throws, or times out, the interceptor places an
/// [OfflineConnectionDioException] in [DioException.error]. Certificate,
/// cancellation, and transform-timeout errors skip the probe.
class OfflineErrorDioInterceptor extends Interceptor {
  /// Creates an [OfflineErrorDioInterceptor] that probes real connectivity
  factory OfflineErrorDioInterceptor() {
    return OfflineErrorDioInterceptor._(InternetConnection.createInstance());
  }

  const OfflineErrorDioInterceptor._(this._internetConnection);

  /// Creates an [OfflineErrorDioInterceptor] with a controllable
  /// [internetConnection] for testing.
  @visibleForTesting
  factory OfflineErrorDioInterceptor.test({
    required InternetConnection internetConnection,
  }) {
    return OfflineErrorDioInterceptor._(internetConnection);
  }

  final InternetConnection _internetConnection;

  static const _checkTimeout = Duration(seconds: 5);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!_shouldCheckConnectivity(err)) {
      handler.next(err);
      return;
    }

    unawaited(_resolveConnectivityError(error: err, handler: handler));
  }

  Future<void> _resolveConnectivityError({
    required DioException error,
    required ErrorInterceptorHandler handler,
  }) async {
    try {
      final isOnline = await _internetConnection.hasInternetAccess.timeout(
        _checkTimeout,
      );
      handler.next(isOnline ? error : _wrapWithOfflineException(error));
    } on Object {
      handler.next(_wrapWithOfflineException(error));
    }
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
      DioExceptionType.transformTimeout => false,
      DioExceptionType.unknown => true,
    };
  }

  DioException _wrapWithOfflineException(DioException err) {
    return DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: OfflineConnectionDioException(
        message: 'No internet connection available to complete the request.',
        cause: err,
      ),
    );
  }
}
