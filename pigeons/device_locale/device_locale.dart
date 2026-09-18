import 'package:pigeon/pigeon.dart';

/// Defines native operations for device locale preferences.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/gen/device_locale/device_locale.g.dart',
    kotlinOut: 'lib/src/gen/device_locale/android/DeviceLocale.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.ventairy.oh_my_flutter.device_locale'),
    swiftOut: 'lib/src/gen/device_locale/apple/DeviceLocale.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'DeviceLocalePigeonError'),
    cppHeaderOut: 'lib/src/gen/device_locale/windows/device_locale.g.h',
    cppSourceOut: 'lib/src/gen/device_locale/windows/device_locale.g.cpp',
    cppOptions: CppOptions(namespace: 'oh_my_flutter::device_locale'),
    dartPackageName: 'oh_my_flutter',
  ),
)
@HostApi()
// Pigeon requires an abstract host API even for a single operation.
// ignore: one_member_abstracts
abstract class DeviceLocaleHostApi {
  /// Returns the configured region identifier when available.
  String? getCountry();
}
