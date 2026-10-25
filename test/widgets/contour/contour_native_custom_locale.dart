import 'dart:ui';

/// Exercises a locale whose paragraph serialization differs from its fields.
class ContourNativeCustomLocale extends Locale {
  const new() : super('en');

  @override
  String toString() => 'ja';
}
