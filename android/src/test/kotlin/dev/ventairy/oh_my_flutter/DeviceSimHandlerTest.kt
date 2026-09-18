package dev.ventairy.oh_my_flutter

import android.content.Context
import android.content.pm.PackageManager
import android.telephony.TelephonyManager
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`

class DeviceSimHandlerTest {
    private val context = mock(Context::class.java)
    private val packageManager = mock(PackageManager::class.java)
    private val telephony = mock(TelephonyManager::class.java)
    private val handler = DeviceSimHandler(context)

    init {
        `when`(context.packageManager).thenReturn(packageManager)
        `when`(packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY_SUBSCRIPTION)).thenReturn(true)
        `when`(context.getSystemService(Context.TELEPHONY_SERVICE)).thenReturn(telephony)
    }

    @Test
    fun `when a SIM country is available, it should return the provider country`() {
        `when`(telephony.simCountryIso).thenReturn("br")
        assertEquals("br", handler.getCountry())
    }

    @Test
    fun `when telephony hardware is unavailable, it should return null`() {
        `when`(packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY_SUBSCRIPTION)).thenReturn(false)
        assertNull(handler.getCountry())
    }

    @Test
    fun `when the telephony service is unavailable, it should return null`() {
        `when`(context.getSystemService(Context.TELEPHONY_SERVICE)).thenReturn(null)
        assertNull(handler.getCountry())
    }

    @Test
    fun `when the SIM country is empty, it should return null`() {
        `when`(telephony.simCountryIso).thenReturn("")
        assertNull(handler.getCountry())
    }

    @Test
    fun `when access is denied, it should return null`() {
        `when`(telephony.simCountryIso).thenThrow(SecurityException("denied"))
        assertNull(handler.getCountry())
    }

    @Test
    fun `when the native lookup fails, it should return null`() {
        `when`(telephony.simCountryIso).thenThrow(IllegalStateException("unavailable"))
        assertNull(handler.getCountry())
    }

    @Test
    fun `when the default SIM changes, it should read the new country`() {
        `when`(telephony.simCountryIso).thenReturn("br", "us")
        assertEquals(listOf("br", "us"), listOf(handler.getCountry(), handler.getCountry()))
    }
}
