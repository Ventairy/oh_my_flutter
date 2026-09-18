package dev.ventairy.oh_my_flutter

import android.app.LocaleManager
import android.content.Context
import android.content.res.Resources
import android.os.Build
import androidx.annotation.ChecksSdkIntAtLeast
import androidx.annotation.RequiresApi
import dev.ventairy.oh_my_flutter.device_locale.DeviceLocaleHostApi
import java.util.Locale

/** Reads the user's system region without app-language overrides. */
internal class DeviceLocaleHandler(
    private val context: Context,
    private val sdkInt: Int = Build.VERSION.SDK_INT,
    private val legacyLocale: () -> Locale? = {
        val locales = Resources.getSystem().configuration.locales
        if (locales.isEmpty) null else locales[0]
    },
) : DeviceLocaleHostApi {
    override fun getCountry(): String? {
        return try {
            val locale = if (supportsSystemLocales()) readSystemLocale() else legacyLocale()
            if (locale == null) return null
            val override = locale.getUnicodeLocaleType("rg")
            if (override != null) {
                // An explicit but unusable region must not fall back to the language region.
                if (!override.matches(Regex("[a-zA-Z]{2}[zZ]{4}"))) return null
                return override.substring(0, 2).uppercase(Locale.ROOT)
            }
            locale.country.takeIf { it.isNotEmpty() }
        } catch (_: RuntimeException) {
            null
        }
    }

    @ChecksSdkIntAtLeast(api = 33)
    private fun supportsSystemLocales(): Boolean = sdkInt >= 33

    @RequiresApi(33)
    private fun readSystemLocale(): Locale? {
        val manager = context.getSystemService(LocaleManager::class.java) ?: return null
        val locales = manager.systemLocales
        return if (locales.isEmpty) null else locales[0]
    }
}
