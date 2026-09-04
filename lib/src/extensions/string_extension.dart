/// Utilities for [String] values.
///
/// See the [string classification guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/extensions/string.md)
/// for usage examples and value classifications.
extension StringExtension on String {
  /// Whether this non-empty value contains only ASCII digits from `0` to `9`.
  bool get isDigitsOnly {
    if (isEmpty) return false;

    for (final codeUnit in codeUnits) {
      if (codeUnit < 0x30 || codeUnit > 0x39) return false;
    }

    return true;
  }
}
