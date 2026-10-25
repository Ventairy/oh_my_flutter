import 'dart:ui';

/// Fails one requested feature read while leaving later key checks usable.
class ContourNativeThrowingFeature extends FontFeature {
  /// Creates the ordinary kerning feature until [armOneRead] is enabled.
  new() : super('kern');

  /// Whether the next [feature] read should throw and immediately disarm itself.
  bool armOneRead = false;

  @override
  String get feature {
    if (armOneRead) {
      armOneRead = false;
      throw StateError('The armed native proof feature read failed.');
    }
    return super.feature;
  }
}
