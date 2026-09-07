import 'package:flutter_test/flutter_test.dart';

import '../../../tool/country_names/country_names_encoder.dart';

void main() {
  late List<int> input;
  late CountryNamesEncodedData data;

  setUp(() {
    input = [1, 2, 3];
    data = CountryNamesEncodedData(rawBytes: input, compressedBytes: input, catalogCount: 2, localeCount: 3);
  });

  test('when source bytes change, it should preserve the original raw payload', () {
    input[0] = 9;
    expect(data.rawBytes, [1, 2, 3]);
  });

  test('when source bytes change, it should preserve the compressed payload', () {
    input[0] = 9;
    expect(data.compressedBytes, [1, 2, 3]);
  });

  test('when callers modify raw bytes, it should reject the mutation', () {
    expect(() => data.rawBytes[0] = 9, throwsUnsupportedError);
  });

  test('when callers modify compressed bytes, it should reject the mutation', () {
    expect(() => data.compressedBytes[0] = 9, throwsUnsupportedError);
  });

  test('when compressed length is odd, it should pad the final packed word with zero', () {
    expect(data.packedString.codeUnits, [0x0201, 0x0003]);
  });

  test('when bytes contain every bit, it should preserve them in packed words', () {
    final allBits = CountryNamesEncodedData(
      rawBytes: const [],
      compressedBytes: const [0xff, 0xff, 0, 0xd8],
      catalogCount: 0,
      localeCount: 0,
    );
    expect(allBits.packedString.codeUnits, [0xffff, 0xd800]);
  });
}
