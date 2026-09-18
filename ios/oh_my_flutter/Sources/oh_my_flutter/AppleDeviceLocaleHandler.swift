import Foundation

/// Reads the user's regional preference from Foundation.
final class AppleDeviceLocaleHandler: DeviceLocaleHostApi {
  private let localeProvider: () -> Locale

  init(localeProvider: @escaping () -> Locale = { Locale.autoupdatingCurrent }) {
    self.localeProvider = localeProvider
  }

  func getCountry() throws -> String? {
    let locale = localeProvider()
    if #available(iOS 16, macOS 13, *) {
      return locale.region?.identifier
    }
    return Self.legacyCountry(for: locale)
  }

  static func legacyCountry(for locale: Locale) -> String? {
    (locale as NSLocale).object(forKey: .countryCode) as? String
  }
}
