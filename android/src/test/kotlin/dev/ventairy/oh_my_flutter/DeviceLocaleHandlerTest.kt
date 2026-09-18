package dev.ventairy.oh_my_flutter

import android.app.LocaleManager
import android.content.Context
import android.os.LocaleList
import java.util.Locale
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`

class DeviceLocaleHandlerTest {
    private val context = mock(Context::class.java)
    private val manager = mock(LocaleManager::class.java)
    private val locales = mock(LocaleList::class.java)

    init {
        `when`(context.getSystemService(LocaleManager::class.java)).thenReturn(manager)
        `when`(manager.systemLocales).thenReturn(locales)
        `when`(locales.isEmpty).thenReturn(false)
    }

    @Test
    fun `when an app language differs, it should read the system country`() {
        `when`(locales[0]).thenReturn(Locale.US)
        assertEquals("US", DeviceLocaleHandler(context, 33) { Locale.FRANCE }.getCountry())
    }

    @Test
    fun `when Android is older, it should read the legacy system locale`() {
        assertEquals("BR", DeviceLocaleHandler(context, 24) { Locale.forLanguageTag("en-BR") }.getCountry())
    }

    @Test
    fun `when a region override exists, it should take priority`() {
        assertEquals("BR", DeviceLocaleHandler(context, 24) { Locale.forLanguageTag("en-US-u-rg-brzzzz") }.getCountry())
    }

    @Test
    fun `when an override is malformed, it should return null`() {
        assertNull(DeviceLocaleHandler(context, 24) { Locale.forLanguageTag("en-US-u-rg-invalid") }.getCountry())
    }

    @Test
    fun `when an override is a macroregion, it should return null`() {
        assertNull(DeviceLocaleHandler(context, 24) { Locale.forLanguageTag("en-US-u-rg-419zzzz") }.getCountry())
    }

    @Test
    fun `when only a language exists, it should return null`() {
        assertNull(DeviceLocaleHandler(context, 24) { Locale.ENGLISH }.getCountry())
    }

    @Test
    fun `when system locales are empty, it should return null`() {
        `when`(locales.isEmpty).thenReturn(true)
        assertNull(DeviceLocaleHandler(context, 33).getCountry())
    }

    @Test
    fun `when the system service is missing, it should return null`() {
        `when`(context.getSystemService(LocaleManager::class.java)).thenReturn(null)
        assertNull(DeviceLocaleHandler(context, 33).getCountry())
    }

    @Test
    fun `when reading fails, it should return null`() {
        `when`(manager.systemLocales).thenThrow(IllegalStateException("unavailable"))
        assertNull(DeviceLocaleHandler(context, 33).getCountry())
    }

    @Test
    fun `when preferences change, it should read the new country`() {
        `when`(locales[0]).thenReturn(Locale.US, Locale.FRANCE)
        val handler = DeviceLocaleHandler(context, 33)
        assertEquals(listOf("US", "FR"), listOf(handler.getCountry(), handler.getCountry()))
    }
}
