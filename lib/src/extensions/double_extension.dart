/// Utilities for [double] values.
///
/// See the [double validation guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/extensions/double.md)
/// for usage examples and value classifications.
extension DoubleExtension on double {
  /// Whether this value is finite and strictly greater than zero.
  ///
  /// Returns `false` for zero, negative values, infinities, and `NaN`.
  bool get isPositiveFinite => isFinite && this > 0;
}
