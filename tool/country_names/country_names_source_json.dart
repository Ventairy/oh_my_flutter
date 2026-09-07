part of 'country_names_source.dart';

final class _CountryNamesSourceJson {
  const _CountryNamesSourceJson({required this.label, required this.uri, required this.value});

  static final _localePattern = RegExp(
    r'^[a-z]{2,8}(?:-[A-Z][a-z]{3})?(?:-(?:[A-Z]{2}|[0-9]{3}))?(?:-(?:[a-z0-9]{5,8}|[0-9][a-z0-9]{3}))*$',
  );

  final String label;
  final Uri uri;
  final Map<String, Object?> value;

  StateError failure(String cause) => StateError('Invalid CLDR $label ($uri): $cause');

  bool validLocale(String locale) => locale == 'root' || _localePattern.hasMatch(locale);

  Object? _at(List<String> path) {
    Object? current = value;
    for (final component in path) {
      if (current is! Map<String, Object?> || !current.containsKey(component)) {
        throw failure('missing expected JSON section "${path.join('.')}"');
      }
      current = current[component];
    }
    return current;
  }

  Map<String, Object?> object(List<String> path) {
    final result = _at(path);
    if (result is! Map<String, Object?>) throw failure('expected JSON object "${path.join('.')}"');
    return result;
  }

  List<Object?> list(List<String> path) {
    final result = _at(path);
    if (result is! List<Object?>) throw failure('expected JSON list "${path.join('.')}"');
    return result;
  }

  List<String> localeList(List<String> path) {
    final result = <String>[];
    final seen = <String>{};
    for (final value in list(path)) {
      if (value is! String || !validLocale(value)) {
        throw failure('invalid locale identifier "$value" in "${path.join('.')}"');
      }
      if (!seen.add(value)) throw failure('duplicate locale identifier "$value"');
      result.add(value);
    }
    if (result.isEmpty) throw failure('empty locale list "${path.join('.')}"');
    return result;
  }

  Map<String, String> localeMap(List<String> path) {
    final result = <String, String>{};
    for (final entry in object(path).entries) {
      final target = entry.value;
      if (!validLocale(entry.key) || target is! String || !validLocale(target)) {
        throw failure('invalid locale mapping "${entry.key}": "$target"');
      }
      result[entry.key] = target;
    }
    return result;
  }
}
