import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lzma/lzma.dart';
import 'package:oh_my_flutter/src/country/country_names_lzma.dart';

void main() {
  final random = Random(18347);
  for (final fixture in <(String, List<int>)>[
    ('an empty stream', []),
    ('a single literal', [42]),
    ('all byte values', List.generate(256, (index) => index)),
    ('a long repeated byte', List.filled(20000, 42)),
    ('overlapping matches', utf8.encode('abcdefghabcdefghabcd' * 400)),
    ('localized Unicode text', utf8.encode('中国 中國 Кина Kina Estados Unidos da América 🌎\n' * 200)),
    ('incompressible data', List.generate(10000, (_) => random.nextInt(256))),
    (
      'widely separated repeated blocks',
      [
        ...List.generate(5000, (index) => index & 0xff),
        ...List.filled(20000, 7),
        ...List.generate(5000, (index) => index & 0xff),
      ],
    ),
  ]) {
    test('when decoding ${fixture.$1}, it should reproduce every source byte', () {
      final encoded = Uint8List.fromList(lzma.encode(fixture.$2));
      expect(CountryNamesLzma.decode(encoded), fixture.$2);
    });
  }

  test('when the header is truncated, it should reject the input', () {
    expect(() => CountryNamesLzma.decode(Uint8List(12)), throwsFormatException);
  });

  test('when properties are invalid, it should reject the input', () {
    final encoded = Uint8List.fromList(lzma.encode([1, 2, 3]))..[0] = 225;
    expect(() => CountryNamesLzma.decode(encoded), throwsFormatException);
  });

  test('when the output size is unspecified, it should reject the input', () {
    final encoded = Uint8List.fromList(lzma.encode([1, 2, 3]))..fillRange(5, 13, 255);
    expect(() => CountryNamesLzma.decode(encoded), throwsFormatException);
  });

  test('when the range prefix is invalid, it should reject the input', () {
    final encoded = Uint8List.fromList(lzma.encode([1, 2, 3]))..[13] = 1;
    expect(() => CountryNamesLzma.decode(encoded), throwsFormatException);
  });

  test('when the payload is truncated, it should reject the input', () {
    final encoded = Uint8List.fromList(lzma.encode(List.generate(4096, (index) => index & 0xff)));
    expect(() => CountryNamesLzma.decode(encoded.sublist(0, encoded.length ~/ 2)), throwsFormatException);
  });

  test('when matches exceed the declared output size, it should reject the input', () {
    final encoded = Uint8List.fromList(lzma.encode(List.filled(1000, 42)));
    ByteData.sublistView(encoded).setUint32(5, 100, Endian.little);
    expect(() => CountryNamesLzma.decode(encoded), throwsFormatException);
  });
}
