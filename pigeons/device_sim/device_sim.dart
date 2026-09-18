import 'package:pigeon/pigeon.dart';

/// Defines the Android host operations for SIM access.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/gen/device_sim/device_sim.g.dart',
    kotlinOut: 'lib/src/gen/device_sim/android/DeviceSim.g.kt',
    kotlinOptions: KotlinOptions(package: 'dev.ventairy.oh_my_flutter.device_sim'),
    dartPackageName: 'oh_my_flutter',
  ),
)
@HostApi()
// Pigeon requires an abstract host API even for a single operation.
// ignore: one_member_abstracts
abstract class DeviceSimHostApi {
  /// Returns the default SIM provider's ISO alpha-2 country code, if available.
  String? getCountry();
}
