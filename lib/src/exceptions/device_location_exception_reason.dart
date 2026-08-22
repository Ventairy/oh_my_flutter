/// Identifies why a device-location operation could not be completed.
enum DeviceLocationExceptionReason {
  /// The device's system location services are turned off or unavailable.
  servicesDisabled,

  /// The user denied foreground location permission for this request.
  permissionDenied,

  /// The app cannot request foreground location access again.
  ///
  /// Recovery can require a change in system settings or system policy.
  permissionPermanentlyDenied,

  /// The host application is missing required platform permission setup.
  configurationMissing,

  /// The current operating system does not support device location.
  unsupportedPlatform,

  /// A native location operation could not be completed.
  operationUnavailable,

  /// The platform could not provide usable current coordinates.
  coordinatesUnavailable,
}
