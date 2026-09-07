part of 'country_names_browser.dart';

@JS('Intl.DisplayNames')
extension type _CountryNamesDisplayNames._(JSObject _) implements JSObject {
  external factory _CountryNamesDisplayNames(JSArray<JSString> locales, _CountryNamesDisplayOptions options);

  external static JSArray<JSString> supportedLocalesOf(JSArray<JSString> locales);

  external String? of(String countryCode);
}
