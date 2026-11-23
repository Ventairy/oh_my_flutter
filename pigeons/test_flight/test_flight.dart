import 'package:pigeon/pigeon.dart';

/// Reads the distribution source of the running iOS app.
@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/gen/test_flight/test_flight.g.dart',
    swiftOut: 'lib/src/gen/test_flight/apple/TestFlight.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'TestFlightPigeonError'),
    dartPackageName: 'oh_my_flutter',
  ),
)
@HostApi()
// Pigeon requires an abstract host API for this operation.
abstract class TestFlightHostApi {
  /// Returns null when Apple cannot determine the installation source.
  @async
  bool? checkTestFlight();
}
