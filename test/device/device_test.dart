import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

part '_fake_device_display.dart';
part '_fake_device_location.dart';
part '_fake_device_sim.dart';
part '_fake_device_locale.dart';

void main() {
  group('Device', () {
    test('when created with defaults, it should provide locale access', () {
      expect(const Device().locale, isA<DeviceLocale>());
    });
    test('when a locale utility is supplied, it should retain the substitution', () {
      const locale = _FakeDeviceLocale();
      expect(const Device(locale: locale).locale, same(locale));
    });
    test('when created with defaults, it should provide SIM access', () {
      expect(const Device().sim, isA<DeviceSim>());
    });
    test('when a SIM utility is supplied, it should retain the substitution', () {
      const sim = _FakeDeviceSim();
      expect(const Device(sim: sim).sim, same(sim));
    });
    test(
      'when created with defaults, it should provide device location',
      () {
        expect(const Device().location, isA<DeviceLocation>());
      },
    );

    test(
      'when created with defaults, it should provide device display',
      () {
        expect(const Device().display, isA<DeviceDisplay>());
      },
    );

    test(
      'when utilities are supplied, it should retain the substitutions',
      () {
        const location = _FakeDeviceLocation();
        const display = _FakeDeviceDisplay();

        expect(
          const Device(location: location, display: display),
          isA<Device>()
              .having((device) => device.location, 'location', same(location))
              .having((device) => device.display, 'display', same(display)),
        );
      },
    );
  });
}
