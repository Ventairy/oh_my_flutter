import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('DeviceLocationCoordinates', () {
    test(
      'when values match, it should use value equality',
      () {
        expect(
          const DeviceLocationCoordinates(latitude: 10, longitude: 20, accuracy: 5),
          const DeviceLocationCoordinates(latitude: 10, longitude: 20, accuracy: 5),
        );
      },
    );

    test(
      'when values match, it should use equal hash codes',
      () {
        expect(
          const DeviceLocationCoordinates(
            latitude: 10,
            longitude: 20,
            accuracy: 5,
          ).hashCode,
          const DeviceLocationCoordinates(
            latitude: 10,
            longitude: 20,
            accuracy: 5,
          ).hashCode,
        );
      },
    );

    test(
      'when one value differs, it should not use value equality',
      () {
        expect(
          const DeviceLocationCoordinates(latitude: 10, longitude: 20, accuracy: 5),
          isNot(
            const DeviceLocationCoordinates(latitude: 10, longitude: 20, accuracy: 6),
          ),
        );
      },
    );

    test(
      'when latitude is outside its coordinate range, it should fail its contract assertion',
      () {
        expect(
          () => DeviceLocationCoordinates(latitude: 91, longitude: 20, accuracy: 5),
          throwsAssertionError,
        );
      },
    );

    test(
      'when longitude is outside its coordinate range, it should fail its contract assertion',
      () {
        expect(
          () => DeviceLocationCoordinates(latitude: 10, longitude: 181, accuracy: 5),
          throwsAssertionError,
        );
      },
    );

    test(
      'when accuracy is negative, it should fail its contract assertion',
      () {
        expect(
          () => DeviceLocationCoordinates(latitude: 10, longitude: 20, accuracy: -1),
          throwsAssertionError,
        );
      },
    );

    test(
      'when accuracy is infinite, it should fail its contract assertion',
      () {
        expect(
          () => DeviceLocationCoordinates(
            latitude: 10,
            longitude: 20,
            accuracy: double.infinity,
          ),
          throwsAssertionError,
        );
      },
    );
  });
}
