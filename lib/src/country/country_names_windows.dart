import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../gen/country_names_windows.g.dart';
import 'country_names_bundle.dart';

/// Reads country names supplied by Windows, including older Windows releases.
final class CountryNamesWindows {
  CountryNamesWindows._(this._bindings);

  /// Uses controlled bindings to exercise native results and fallback behavior.
  @visibleForTesting
  CountryNamesWindows.test({required CountryNamesWindowsBindings? bindings}) : this._(bindings);

  /// The country-name source for this Windows installation.
  static final instance = CountryNamesWindows._(_loadBindings());

  final CountryNamesWindowsBindings? _bindings;

  /// Returns a localized country name, or null when the language is unavailable.
  String? displayName(String iso2, String localeTag) {
    final bindings = _bindings;
    if (bindings == null) return CountryNamesBundle.instance.displayName(iso2, localeTag);
    return using((arena) {
      final country = 'und_$iso2'.toNativeUtf8(allocator: arena).cast<Char>();
      final locale = localeTag.replaceAll('-', '_').toNativeUtf8(allocator: arena).cast<Char>();
      final status = arena<Int>();
      final length = bindings.uloc_getDisplayCountry(country, locale, nullptr, 0, status);
      if (length <= 0 || length >= 0x7fffffff) return null;
      if (status.value > 0 && status.value != UErrorCode.U_BUFFER_OVERFLOW_ERROR.value) return null;
      final buffer = arena<Uint16>(length + 1);
      status.value = UErrorCode.U_ZERO_ERROR.value;
      final written = bindings.uloc_getDisplayCountry(country, locale, buffer, length + 1, status);
      // Never substitute the machine's default language for the requested one.
      if (status.value > 0 || status.value == UErrorCode.U_USING_DEFAULT_WARNING.value) return null;
      if (written <= 0 || written > length) return null;
      final name = String.fromCharCodes(buffer.asTypedList(written));
      return name == iso2 ? null : name;
    });
  }

  static CountryNamesWindowsBindings? _loadBindings() {
    try {
      final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
      final libraryPath = '$systemRoot${Platform.pathSeparator}System32${Platform.pathSeparator}icu.dll';
      final library = DynamicLibrary.open(
        libraryPath,
      );
      if (!library.providesSymbol('uloc_getDisplayCountry')) return null;
      return CountryNamesWindowsBindings(library);
      // DynamicLibrary.open uses ArgumentError for a missing system DLL.
      // ignore: avoid_catching_errors
    } on ArgumentError {
      // The SDK reports dynamic-library loader failures as ArgumentError.
      // Windows before 1903 does not provide the combined system ICU library.
      return null;
    }
  }
}
