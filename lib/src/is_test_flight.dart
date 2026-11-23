import 'package:flutter/foundation.dart';

import 'gen/test_flight/test_flight.g.dart';
import 'test_flight/test_flight_lookup.dart';

final _lookup = TestFlightLookup(TestFlightHostApi().checkTestFlight);

/// Checks whether this app was installed through TestFlight on an iPhone or iPad.
///
/// Use `if (await isTestFlight)` to offer beta testers features such as a
/// feedback button. Read after Flutter binding initialization. Returns false
/// before iOS or iPadOS 17.4, on other platforms, or if Apple cannot confirm
/// the source. A later read retries a temporarily unavailable source.
///
/// See the [TestFlight detection guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/utilities/is_test_flight.md).
Future<bool> get isTestFlight =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS ? _lookup.value : Future.value(false);
