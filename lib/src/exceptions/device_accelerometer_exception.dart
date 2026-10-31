import 'device_accelerometer_exception_reason.dart';

/// Helps callers handle unavailable or failed accelerometer access.
///
/// Use [reason] for application-owned recovery and [cause] for diagnostics.
final class DeviceAccelerometerException implements Exception {
  /// Creates an exception explaining why accelerometer access failed.
  const new(this.reason, {this.cause});

  /// Why the requested access could not be completed.
  final DeviceAccelerometerExceptionReason reason;

  /// The underlying platform failure, when available.
  final Object? cause;

  @override
  String toString() => 'DeviceAccelerometerException(reason: ${reason.name})';
}
