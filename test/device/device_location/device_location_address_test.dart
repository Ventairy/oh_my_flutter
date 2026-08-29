import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  const coordinates = DeviceLocationCoordinates(
    latitude: -23.556391,
    longitude: -46.844076,
    accuracy: 8.5,
  );

  group('DeviceLocationAddress', () {
    test(
      'when values match, it should use value equality',
      () {
        expect(
          const DeviceLocationAddress(
            coordinates: coordinates,
            formattedAddress: 'Rua Harmonia, 797',
            street: 'Rua Harmonia',
          ),
          const DeviceLocationAddress(
            coordinates: coordinates,
            formattedAddress: 'Rua Harmonia, 797',
            street: 'Rua Harmonia',
          ),
        );
      },
    );

    test(
      'when values match, it should use equal hash codes',
      () {
        expect(
          const DeviceLocationAddress(
            coordinates: coordinates,
            city: 'São Paulo',
          ).hashCode,
          const DeviceLocationAddress(
            coordinates: coordinates,
            city: 'São Paulo',
          ).hashCode,
        );
      },
    );

    test(
      'when one value differs, it should not use value equality',
      () {
        expect(
          const DeviceLocationAddress(
            coordinates: coordinates,
            street: 'Rua Harmonia',
          ),
          isNot(
            const DeviceLocationAddress(
              coordinates: coordinates,
              street: 'Rua Girassol',
            ),
          ),
        );
      },
    );

    test(
      'when every address value is absent, it should fail its contract assertion',
      () {
        expect(
          () => DeviceLocationAddress(coordinates: coordinates),
          throwsAssertionError,
        );
      },
    );

    test(
      'when an address value is empty, it should fail its contract assertion',
      () {
        expect(
          () => DeviceLocationAddress(coordinates: coordinates, street: ''),
          throwsAssertionError,
        );
      },
    );

    test(
      'when a country code does not contain two characters, it should fail its contract assertion',
      () {
        expect(
          () => DeviceLocationAddress(
            coordinates: coordinates,
            countryCode: 'BRA',
          ),
          throwsAssertionError,
        );
      },
    );
  });
}
