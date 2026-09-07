package dev.ventairy.oh_my_flutter

import java.util.Locale
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class CountryNamesBridgeTest {
    @Test
    fun `when Portuguese is requested, it should localize the country`() {
        assertEquals("Brasil", CountryNamesBridge.displayName("BR", "pt-BR"))
    }

    @Test
    fun `when Traditional Chinese is requested, it should preserve the script`() {
        assertEquals("美國", CountryNamesBridge.displayName("US", "zh-Hant"))
    }

    @Test
    fun `when an unknown language is requested, it should allow English fallback`() {
        val previous = Locale.getDefault()
        try {
            Locale.setDefault(Locale.forLanguageTag("pt"))
            assertNull(CountryNamesBridge.displayName("BR", "zzz"))
        } finally {
            Locale.setDefault(previous)
        }
    }

    @Test
    fun `when Ascension is requested, it should resolve the extended code`() {
        assertEquals("Ascension Island", CountryNamesBridge.displayName("AC", "en"))
    }

    @Test
    fun `when Tristan da Cunha is requested, it should resolve the extended code`() {
        assertEquals("Tristan da Cunha", CountryNamesBridge.displayName("TA", "en"))
    }

    @Test
    fun `when Kosovo is requested, it should resolve the extended code`() {
        assertEquals("Kosovo", CountryNamesBridge.displayName("XK", "en"))
    }
}
