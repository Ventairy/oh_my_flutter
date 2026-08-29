import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:record_use/record_use.dart';

/// Defines the iOS native asset used by `DeviceLocation` build hooks.
abstract final class DeviceLocationCLibrary {
  /// The native-asset identifier referenced by the Dart FFI declarations.
  static const assetName = 'src/device/device_location/apple_device_location/apple_device_location_platform.dart';

  /// The bundled framework name.
  static const libraryName = 'oh_my_flutter_device_location';

  static const _dartLibrary = Library(
    'package:oh_my_flutter/src/device/device_location/apple_device_location/apple_device_location_platform.dart',
  );
  static const _platformClass = Class(
    'AppleDeviceLocationPlatform',
    _dartLibrary,
  );
  static const _nativeMethods = <Method>[
    Method('_nativeIsServiceEnabled', _platformClass),
    Method('_nativeCheckPermission', _platformClass),
    Method('_nativeRequestPermission', _platformClass),
    Method('_nativeRequestCoordinates', _platformClass),
    Method('_nativeRequestAddress', _platformClass),
    Method('_nativeAllocate', _platformClass),
    Method('_nativeFree', _platformClass),
    Method('_nativeOpenSettings', _platformClass),
  ];

  /// The Core Location implementation compiled before reachability linking.
  static final library = CLibrary(
    name: libraryName,
    assetName: assetName,
    sources: const ['src/device_location/apple_device_location.m'],
    includes: const ['src/device_location'],
    frameworks: const [
      'Foundation',
      'CoreLocation',
      'MapKit',
      'Contacts',
      'UIKit',
    ],
    flags: const [
      '-fobjc-arc',
      '-mios-version-min=15.0',
      '-Qunused-arguments',
    ],
    language: Language.objectiveC,
  );

  /// Reports whether compiled code can call a DeviceLocation native method.
  static bool isReachable(Recordings recordedUses) {
    return recordedUses.calls.entries.any(
      (entry) => _nativeMethods.contains(entry.key) && entry.value.isNotEmpty,
    );
  }
}
