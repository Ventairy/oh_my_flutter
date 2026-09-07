import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:objective_c/objective_c.dart' show CFString;

import '../gen/country_names_apple.g.dart';

/// Reads the country names supplied by the installed Apple operating system.
abstract final class CountryNamesApple {
  /// Returns a localized country name, or null when the system has none.
  static String? displayName(String iso2, String localeTag) {
    return using((arena) {
      final identifier = _string(localeTag, arena);
      final country = _string(iso2, arena);
      if (identifier == nullptr || country == nullptr) return null;
      final locale = _bindings.CFLocaleCreate(nullptr, identifier);
      if (locale == nullptr) return null;
      arena.onReleaseAll(() => _bindings.CFRelease(locale.cast()));
      final name = _bindings.CFLocaleCopyDisplayNameForPropertyValue(
        locale,
        _bindings.kCFLocaleCountryCode,
        country,
      );
      if (name == nullptr) return null;
      arena.onReleaseAll(() => _bindings.CFRelease(name.cast()));
      // Each UTF-16 code unit needs at most three UTF-8 bytes, plus the terminator.
      final capacity = _bindings.CFStringGetLength(name) * 3 + 1;
      final bytes = arena<Uint8>(capacity);
      if (_bindings.CFStringGetCString(name, bytes.cast(), capacity, _utf8Encoding) == 0) return null;
      final buffer = bytes.asTypedList(capacity);
      final end = buffer.indexOf(0);
      if (end < 0) return null;
      final result = utf8.decode(buffer.sublist(0, end));
      return result.isEmpty || result == iso2 ? null : result;
    });
  }

  static Pointer<CFString> _string(String value, Arena arena) {
    final bytes = utf8.encode(value);
    final pointer = arena<Uint8>(bytes.length);
    pointer.asTypedList(bytes.length).setAll(0, bytes);
    final string = _bindings.CFStringCreateWithBytes(
      nullptr,
      pointer.cast(),
      bytes.length,
      _utf8Encoding,
      0,
    );
    if (string != nullptr) arena.onReleaseAll(() => _bindings.CFRelease(string.cast()));
    return string;
  }

  static const _utf8Encoding = 0x08000100;
  static final _bindings = CountryNamesAppleBindings(
    DynamicLibrary.open('/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation'),
  );
}
