import 'package:flutter/foundation.dart';

import 'contour_native_port_session.dart';

/// Selects native tracing only when a supported large capture fits its budget.
class ContourNativeTracePolicy {
  /// Uses the actual Android host without opening or initializing a native port.
  factory() => ContourNativeTracePolicy._(ContourNativePortSession.isAndroid);

  const new _(this._isAndroid);

  /// Exercises platform eligibility without replacing the production platform.
  @visibleForTesting
  const new test({required bool isAndroid}) : this._(isAndroid);

  /// Retains Dart tracing for captures below this physical pixel count.
  static const int minimumPixels = 512 * 1024;

  /// Reserves fixed native job bookkeeping before capturing source pixels.
  static const int jobOverheadBytes = 4096;

  final bool _isAndroid;

  /// Reports whether this policy permits native tracing on its host.
  bool get isSupported => _isAndroid;

  /// Returns optional bookkeeping bytes, or zero to preserve the Dart path.
  int additionalSourceBytesWithinBudget({
    required int pixels,
    required int legacyBytes,
    required int budgetBytes,
  }) {
    assert(pixels > 0, 'The source pixel count must be positive.');
    assert(legacyBytes > 0, 'The baseline allowance must be positive.');
    assert(budgetBytes > 0, 'The work capacity must be positive.');
    return _isAndroid && pixels >= minimumPixels && legacyBytes + jobOverheadBytes <= budgetBytes
        ? jobOverheadBytes
        : 0;
  }
}
