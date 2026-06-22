import 'package:dio/dio.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Thrown when the device has no active internet connection and a network
/// request cannot be completed.
///
/// [OmfOfflineErrorDioInterceptor] sets this exception as the [DioException.error]
/// on a wrapped [DioException] once a real connectivity check confirms the
/// device is offline.
///
/// ```dart
/// try {
///   await dio.get('/jobs');
/// } on DioException catch (e) {
///   if (e.error is OmfOfflineConnectionDioException) {
///     showOfflineBanner();
///   }
/// }
/// ```
class OmfOfflineConnectionDioException implements Exception {
  /// Creates an [OmfOfflineConnectionDioException].
  ///
  /// [message] describes the offline condition. [cause] is the original error
  /// that triggered the connectivity check, when available.
  const OmfOfflineConnectionDioException({required this.message, this.cause});

  /// Human-readable description of why the request is considered offline.
  final String message;

  /// The original error that triggered the offline check, if any.
  final Object? cause;

  @override
  String toString() => 'OfflineConnectionException: $message';
}
