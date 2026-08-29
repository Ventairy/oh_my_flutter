import 'package:meta/meta.dart';

import 'device_location_coordinates.dart';

/// Describes a device-formatted address for geographic [coordinates].
///
/// Address components are nullable because device geocoders can return
/// different levels of detail for different places. Use [formattedAddress]
/// when the platform provides a display-ready address, or select a component
/// such as [street] for a more focused label.
///
/// See the [device location guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/utilities/device_location.md)
/// for address lookup, localization, and availability guidance.
@immutable
final class DeviceLocationAddress {
  /// Creates an address associated with [coordinates].
  ///
  /// At least one textual address value must be supplied. Text values must not
  /// be empty; values returned by `DeviceLocation` are also trimmed so
  /// whitespace-only native values become null. When constructing an address
  /// directly, supply [countryCode] as two uppercase ASCII letters.
  const DeviceLocationAddress({
    required this.coordinates,
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
  }) : assert(
         formattedAddress != '' &&
             name != '' &&
             street != '' &&
             streetNumber != '' &&
             neighborhood != '' &&
             district != '' &&
             city != '' &&
             state != '' &&
             postalCode != '' &&
             country != '' &&
             countryCode != '',
         'address values must not be empty',
       ),
       assert(
         formattedAddress != null ||
             name != null ||
             street != null ||
             streetNumber != null ||
             neighborhood != null ||
             district != null ||
             city != null ||
             state != null ||
             postalCode != null ||
             country != null ||
             countryCode != null,
         'at least one address value must be supplied',
       ),
       assert(
         countryCode == null || countryCode.length == 2,
         'countryCode must contain two characters',
       );

  /// The coordinates that were reverse-geocoded for this address.
  final DeviceLocationCoordinates coordinates;

  /// The localized, display-ready address supplied by the device.
  ///
  /// This value can contain line breaks chosen by the platform formatter.
  final String? formattedAddress;

  /// The named place, building, landmark, or feature at the location.
  final String? name;

  /// The street or thoroughfare name, without [streetNumber] when available.
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

  /// The two-letter ISO country or region code, when supplied by the device.
  final String? countryCode;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DeviceLocationAddress &&
            other.coordinates == coordinates &&
            other.formattedAddress == formattedAddress &&
            other.name == name &&
            other.street == street &&
            other.streetNumber == streetNumber &&
            other.neighborhood == neighborhood &&
            other.district == district &&
            other.city == city &&
            other.state == state &&
            other.postalCode == postalCode &&
            other.country == country &&
            other.countryCode == countryCode;
  }

  @override
  int get hashCode => Object.hash(
    coordinates,
    formattedAddress,
    name,
    street,
    streetNumber,
    neighborhood,
    district,
    city,
    state,
    postalCode,
    country,
    countryCode,
  );
}
