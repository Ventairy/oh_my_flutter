import 'package:meta/meta.dart';

/// Describes geographic coordinates reported by the device.
@immutable
final class DeviceLocationCoordinates {
  /// Creates device coordinates with their horizontal [accuracy].
  const DeviceLocationCoordinates({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  }) : assert(
         latitude >= -90 && latitude <= 90,
         'latitude must be between -90 and 90',
       ),
       assert(
         longitude >= -180 && longitude <= 180,
         'longitude must be between -180 and 180',
       ),
       assert(
         accuracy >= 0 && accuracy < double.infinity,
         'accuracy must be finite and not negative',
       );

  /// The latitude in degrees between -90 and 90, inclusive.
  final double latitude;

  /// The longitude in degrees between -180 and 180, inclusive.
  final double longitude;

  /// The estimated horizontal uncertainty in meters.
  ///
  /// A smaller value represents a more precise result. A value of zero can
  /// indicate that the platform did not provide an accuracy estimate.
  final double accuracy;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DeviceLocationCoordinates &&
            other.latitude == latitude &&
            other.longitude == longitude &&
            other.accuracy == accuracy;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracy);

  @override
  String toString() {
    return 'DeviceLocationCoordinates('
        'latitude: $latitude, '
        'longitude: $longitude, '
        'accuracy: $accuracy'
        ')';
  }
}
