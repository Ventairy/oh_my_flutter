/// Describes the application's foreground location permission state.
enum DeviceLocationPermissionStatus {
  /// The user has not responded to a location permission request.
  ///
  /// Android reports [denied] for an ungranted permission because it cannot
  /// reliably distinguish this state from a previous denial.
  notDetermined,

  /// Foreground location access is not granted but can be requested.
  denied,

  /// Foreground location access can only be changed in system settings.
  deniedForever,

  /// A system policy prevents the user from granting location access.
  ///
  /// This state is currently reported by iOS.
  restricted,

  /// Location access is available while the application is in use.
  whileInUse,

  /// Location access is available while the application is in use or in the
  /// background.
  always,
  ;

  /// Whether the application currently has usable location permission.
  bool get isGranted => switch (this) {
    whileInUse || always => true,
    notDetermined || denied || deniedForever || restricted => false,
  };
}
