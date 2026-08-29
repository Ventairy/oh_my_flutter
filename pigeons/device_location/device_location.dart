import 'package:pigeon/pigeon.dart';

// Pigeon resolves types only from its input compilation unit, so this schema
// intentionally keeps its related declarations together.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/device/device_location/pigeon/android_device_location.g.dart',
    dartOptions: DartOptions(),
    kotlinOut: 'android/src/main/kotlin/dev/ventairy/oh_my_flutter/AndroidDeviceLocation.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.ventairy.oh_my_flutter'),
    dartPackageName: 'oh_my_flutter',
  ),
)
/// Defines the Android host operations used by the location implementation.
@HostApi()
abstract class AndroidDeviceLocationApi {
  /// Reports whether Android's system location service is enabled.
  bool isServiceEnabled();

  /// Reports the current Android foreground-location permission.
  AndroidDeviceLocationPermissionStatus checkPermission();

  /// Requests Android foreground-location permission.
  @asyncCallback
  AndroidDeviceLocationPermissionStatus requestPermission();

  /// Retrieves the current Android device coordinates.
  @asyncCallback
  AndroidDeviceCoordinates getCurrentCoordinates();

  /// Returns the device-formatted address for geographic coordinates.
  @asyncCallback
  AndroidDeviceLocationAddress getAddress(
    double latitude,
    double longitude,
    String? localeIdentifier,
    int timeoutMilliseconds,
  );

  /// Opens Android's application-details settings page.
  bool openLocationSettings();
}

/// Describes a failure returned by the Android location implementation.
enum AndroidDeviceLocationFailure {
  /// Android's system location service is disabled.
  servicesDisabled,

  /// Foreground location permission is not granted.
  permissionDenied,

  /// Foreground location permission must be changed in system settings.
  permissionPermanentlyDenied,

  /// Required Android host configuration is missing.
  configurationMissing,

  /// Android could not complete a native operation.
  operationUnavailable,

  /// Android could not provide usable coordinates.
  coordinatesUnavailable,
}

/// Describes Android's foreground-location permission state.
enum AndroidDeviceLocationPermissionStatus {
  /// Foreground location permission can be requested.
  denied,

  /// Foreground location permission must be changed in system settings.
  deniedForever,

  /// Location access is available while the application is in use.
  whileInUse,
}

/// Carries Android coordinates across the package's platform channel.
class AndroidDeviceCoordinates {
  /// Creates a coordinates message with horizontal accuracy.
  AndroidDeviceCoordinates({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  /// The latitude in degrees.
  final double latitude;

  /// The longitude in degrees.
  final double longitude;

  /// The estimated horizontal uncertainty in meters.
  final double accuracy;
}

/// Carries an Android reverse-geocoding result across the platform channel.
class AndroidDeviceLocationAddress {
  /// Creates a message with nullable device-supplied address components.
  AndroidDeviceLocationAddress({
    this.formattedAddress,
    this.name,
    this.street,
    this.streetNumber,
    this.neighborhood,
    this.district,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.countryCode,
  });

  /// The localized, display-ready address.
  final String? formattedAddress;

  /// The named place, building, landmark, or feature.
  final String? name;

  /// The street or thoroughfare name.
  final String? street;

  /// The building or street number.
  final String? streetNumber;

  /// The neighborhood or sublocality.
  final String? neighborhood;

  /// The county, district, or subadministrative area.
  final String? district;

  /// The city or locality.
  final String? city;

  /// The state, province, or administrative area.
  final String? state;

  /// The postal or ZIP code.
  final String? postalCode;

  /// The localized country or region name.
  final String? country;

  /// The two-letter country or region code.
  final String? countryCode;
}
