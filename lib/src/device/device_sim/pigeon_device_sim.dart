import 'package:meta/meta.dart';

import '../../gen/device_sim/device_sim.g.dart';
import 'device_sim_platform.dart';

/// Reads SIM information through the Android host API.
final class PigeonDeviceSimPlatform extends DeviceSimPlatform {
  /// Creates the Android SIM implementation.
  PigeonDeviceSimPlatform() : _api = DeviceSimHostApi();

  /// Creates an implementation backed by a test host API.
  @visibleForTesting
  PigeonDeviceSimPlatform.test(this._api);

  final DeviceSimHostApi _api;

  @override
  Future<String?> getCountry() => _api.getCountry();
}
