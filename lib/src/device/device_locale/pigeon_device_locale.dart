import 'package:meta/meta.dart';

import '../../gen/device_locale/device_locale.g.dart';
import 'device_locale_platform.dart';

/// Reads locale information through the native host API.
final class PigeonDeviceLocalePlatform extends DeviceLocalePlatform {
  /// Creates the native locale implementation.
  new() : _api = DeviceLocaleHostApi();

  /// Creates an implementation backed by a test host API.
  @visibleForTesting
  new test(this._api);

  final DeviceLocaleHostApi _api;

  @override
  Future<String?> getCountry() => _api.getCountry();
}
