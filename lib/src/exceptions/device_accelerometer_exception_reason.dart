/// Identifies why accelerometer access could not be completed.
enum DeviceAccelerometerExceptionReason {
  /// The current operating system has no implementation in this package.
  unsupportedPlatform,

  /// The device has no available accelerometer.
  sensorUnavailable,

  /// System permissions or policy prevented the requested sensor access.
  permissionDenied,

  /// The platform could not complete the requested operation.
  operationUnavailable,
}
