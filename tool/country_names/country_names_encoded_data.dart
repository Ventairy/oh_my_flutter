part of 'country_names_encoder.dart';

/// Keeps validated country-name payloads ready for deterministic source output.
final class CountryNamesEncodedData {
  /// Takes immutable copies of the original and compressed payloads.
  CountryNamesEncodedData({
    required List<int> rawBytes,
    required List<int> compressedBytes,
    required this.catalogCount,
    required this.localeCount,
  }) : rawBytes = Uint8List.fromList(rawBytes).asUnmodifiableView(),
       compressedBytes = Uint8List.fromList(compressedBytes).asUnmodifiableView();

  /// Complete compact metadata and country-name grid before compression.
  final Uint8List rawBytes;

  /// LZMA ALONE bytes with their known uncompressed length in the header.
  final Uint8List compressedBytes;

  /// Number of distinct country-name grids retained after deduplication.
  final int catalogCount;

  /// Number of catalog, alias, and parent identifiers in the payload.
  final int localeCount;

  /// Stores two compressed bytes in each Dart string code unit.
  ///
  /// The final high byte is zero when the compressed length is odd. Consumers
  /// unpack exactly the length of [compressedBytes], excluding that padding.
  String get packedString => String.fromCharCodes([
    for (var index = 0; index < compressedBytes.length; index += 2)
      compressedBytes[index] | ((index + 1 < compressedBytes.length ? compressedBytes[index + 1] : 0) << 8),
  ]);
}
