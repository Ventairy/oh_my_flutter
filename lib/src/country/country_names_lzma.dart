// Adapted from the LZMA SDK port by Juan Mellado.
// Copyright (c) 2012 Juan Mellado
// SPDX-License-Identifier: MIT
// See the third-party notices distributed with this package.

import 'dart:typed_data';

/// Decodes the bundled country-name data without a runtime codec dependency.
final class CountryNamesLzma {
  CountryNamesLzma._(this._input);

  static const _isMatch = 0;
  static const int _isRep = _isMatch + 192;
  static const int _isRepG0 = _isRep + 12;
  static const int _isRepG1 = _isRepG0 + 12;
  static const int _isRepG2 = _isRepG1 + 12;
  static const int _isRep0Long = _isRepG2 + 12;
  static const int _positionSlot = _isRep0Long + 192;
  static const int _position = _positionSlot + 256;
  static const int _alignment = _position + 114;
  static const int _length = _alignment + 16;
  static const int _repeatedLength = _length + 514;
  static const int _literal = _repeatedLength + 514;

  final Uint8List _input;
  late Uint16List _probabilities;
  int _offset = 13;
  int _range = 0xffffffff;
  int _code = 0;

  /// Expands a complete LZMA-alone stream with a known 32-bit output length.
  ///
  /// Throws [FormatException] for invalid properties, truncated input, invalid
  /// references, or a stream that does not produce its declared output size.
  static Uint8List decode(Uint8List input) => CountryNamesLzma._(input)._decode();

  Uint8List _decode() {
    if (_input.length < 18) throw const FormatException('Truncated country-name LZMA header');
    final property = _input[0];
    if (property >= 225) throw const FormatException('Invalid country-name LZMA properties');
    final contextBits = property % 9;
    final literalPositionBits = (property ~/ 9) % 5;
    final positionBits = property ~/ 45;
    final header = ByteData.sublistView(_input);
    if (header.getUint32(9, Endian.little) != 0) {
      throw const FormatException('Country-name LZMA requires a known 32-bit output length');
    }
    final dictionarySize = header.getUint32(1, Endian.little);
    final output = Uint8List(header.getUint32(5, Endian.little));
    final positionMask = (1 << positionBits) - 1;
    final literalPositionMask = (1 << literalPositionBits) - 1;
    _probabilities = Uint16List(_literal + (0x300 << (contextBits + literalPositionBits)))
      ..fillRange(0, _literal + (0x300 << (contextBits + literalPositionBits)), 1024);

    if (_readByte() != 0) throw const FormatException('Invalid country-name LZMA range prefix');
    for (var index = 0; index < 4; index++) {
      _code = ((_code << 8) | _readByte()) & 0xffffffff;
    }
    var state = 0;
    var repeated0 = 0;
    var repeated1 = 0;
    var repeated2 = 0;
    var repeated3 = 0;
    var position = 0;
    var previousByte = 0;
    while (position < output.length) {
      final positionState = position & positionMask;
      if (_bit(_isMatch + (state << 4) + positionState) == 0) {
        final literalBase =
            _literal +
            0x300 * (((position & literalPositionMask) << contextBits) + (previousByte >> (8 - contextBits)));
        var symbol = 1;
        if (state >= 7) {
          if (repeated0 >= position) throw const FormatException('Invalid country-name LZMA literal reference');
          var matchByte = output[position - repeated0 - 1];
          do {
            final matchBit = (matchByte >> 7) & 1;
            matchByte <<= 1;
            final bit = _bit(literalBase + ((1 + matchBit) << 8) + symbol);
            symbol = (symbol << 1) | bit;
            if (matchBit != bit) break;
          } while (symbol < 0x100);
        }
        while (symbol < 0x100) {
          symbol = (symbol << 1) | _bit(literalBase + symbol);
        }
        previousByte = symbol & 0xff;
        output[position++] = previousByte;
        state = state < 4 ? 0 : (state < 10 ? state - 3 : state - 6);
        continue;
      }

      var length = 0;
      if (_bit(_isRep + state) == 1) {
        if (_bit(_isRepG0 + state) == 0) {
          if (_bit(_isRep0Long + (state << 4) + positionState) == 0) {
            state = state < 7 ? 9 : 11;
            length = 1;
          }
        } else {
          int distance;
          if (_bit(_isRepG1 + state) == 0) {
            distance = repeated1;
          } else {
            if (_bit(_isRepG2 + state) == 0) {
              distance = repeated2;
            } else {
              distance = repeated3;
              repeated3 = repeated2;
            }
            repeated2 = repeated1;
          }
          repeated1 = repeated0;
          repeated0 = distance;
        }
        if (length == 0) {
          length = _decodeLength(_repeatedLength, positionState) + 2;
          state = state < 7 ? 8 : 11;
        }
      } else {
        repeated3 = repeated2;
        repeated2 = repeated1;
        repeated1 = repeated0;
        length = _decodeLength(_length, positionState) + 2;
        state = state < 7 ? 7 : 10;
        final lengthState = length < 6 ? length - 2 : 3;
        final slot = _tree(_positionSlot + (lengthState << 6), 6);
        if (slot < 4) {
          repeated0 = slot;
        } else {
          final directBits = (slot >> 1) - 1;
          repeated0 = (2 | (slot & 1)) << directBits;
          if (slot < 14) {
            repeated0 += _reverseTree(_position + repeated0 - slot - 1, directBits);
          } else {
            repeated0 += (_direct(directBits - 4) << 4) + _reverseTree(_alignment, 4);
          }
        }
      }
      if (repeated0 >= position || repeated0 >= (dictionarySize == 0 ? 1 : dictionarySize)) {
        throw const FormatException('Invalid country-name LZMA match distance');
      }
      if (position + length > output.length) throw const FormatException('Country-name LZMA output exceeds its size');
      for (var index = 0; index < length; index++) {
        output[position] = output[position - repeated0 - 1];
        position++;
      }
      previousByte = output[position - 1];
    }
    return output;
  }

  int _readByte() {
    if (_offset >= _input.length) throw const FormatException('Truncated country-name LZMA stream');
    return _input[_offset++];
  }

  void _normalize() {
    if (_range < 0x1000000) {
      _range = (_range << 8) & 0xffffffff;
      _code = ((_code << 8) | _readByte()) & 0xffffffff;
    }
  }

  int _bit(int index) {
    final probability = _probabilities[index];
    final bound = (_range >>> 11) * probability;
    if (_code < bound) {
      _range = bound;
      _probabilities[index] = probability + ((2048 - probability) >> 5);
      _normalize();
      return 0;
    }
    _range -= bound;
    _code -= bound;
    _probabilities[index] = probability - (probability >> 5);
    _normalize();
    return 1;
  }

  int _direct(int count) {
    var result = 0;
    for (var index = 0; index < count; index++) {
      _range >>>= 1;
      final bit = _code >= _range ? 1 : 0;
      if (bit != 0) _code -= _range;
      result = (result << 1) | bit;
      _normalize();
    }
    return result;
  }

  int _tree(int offset, int depth) {
    var symbol = 1;
    for (var index = 0; index < depth; index++) {
      symbol = (symbol << 1) | _bit(offset + symbol);
    }
    return symbol - (1 << depth);
  }

  int _reverseTree(int offset, int depth) {
    var symbol = 1;
    var result = 0;
    for (var index = 0; index < depth; index++) {
      final bit = _bit(offset + symbol);
      symbol = (symbol << 1) | bit;
      result |= bit << index;
    }
    return result;
  }

  int _decodeLength(int offset, int positionState) {
    if (_bit(offset) == 0) return _tree(offset + 2 + (positionState << 3), 3);
    if (_bit(offset + 1) == 0) return 8 + _tree(offset + 130 + (positionState << 3), 3);
    return 16 + _tree(offset + 258, 8);
  }
}
