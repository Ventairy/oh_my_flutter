package dev.ventairy.oh_my_flutter

import androidx.annotation.Keep
import java.util.Locale

/** Provides Android's country names to the synchronous native bridge. */
@Keep
internal object CountryNamesBridge {
    private val supportedLanguages = Locale.getAvailableLocales()
        .mapTo(HashSet()) { it.language }

    @JvmStatic
    fun displayName(iso2: String, localeTag: String): String? {
        val locale = Locale.forLanguageTag(localeTag)
        if (locale.language !in supportedLanguages) return null
        val name = Locale.forLanguageTag("und-$iso2").getDisplayCountry(locale)
        return name.takeUnless { it.isBlank() || it == iso2 }
    }
}
