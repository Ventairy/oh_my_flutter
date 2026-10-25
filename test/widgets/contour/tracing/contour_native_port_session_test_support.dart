import 'dart:typed_data';

/// Supplies RGBA fixtures for production native-session tests.
abstract final class ContourNativePortSessionTestSupport {
  /// Creates a transparent RGBA source containing one solid inset rectangle.
  static Uint8List source() {
    final rgba = Uint8List(32 * 32 * 4);
    for (var y = 6; y < 26; y++) {
      for (var x = 6; x < 26; x++) {
        rgba[(y * 32 + x) * 4 + 3] = 255;
      }
    }
    return rgba;
  }
}
