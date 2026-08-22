import 'device_location_exception_reason.dart';

/// Reports why a requested device-location operation could not be completed.
///
/// Switch on [reason] to present application-owned recovery or localized
/// guidance. [cause] is available for diagnostics when the platform supplied
/// an underlying exception.
final class DeviceLocationException implements Exception {
  /// Creates a location exception for [reason].
  const DeviceLocationException(this.reason, {this.cause});

  /// The actionable reason the location operation could not be completed.
  final DeviceLocationExceptionReason reason;

  /// The underlying exception that caused this failure, when available.
  final Object? cause;

  @override
  String toString() => 'DeviceLocationException(reason: ${reason.name})';
}
