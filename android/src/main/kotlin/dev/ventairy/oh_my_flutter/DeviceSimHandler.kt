package dev.ventairy.oh_my_flutter

import android.content.Context
import android.content.pm.PackageManager
import android.telephony.TelephonyManager
import dev.ventairy.oh_my_flutter.device_sim.DeviceSimHostApi

/** Reads the system-default SIM provider's country without requesting permissions. */
internal class DeviceSimHandler(private val context: Context) : DeviceSimHostApi {
    override fun getCountry(): String? {
        return try {
            if (!context.packageManager.hasSystemFeature(PackageManager.FEATURE_TELEPHONY_SUBSCRIPTION)) {
                return null
            }
            val telephony = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
            telephony?.simCountryIso?.takeIf { it.isNotBlank() }
        } catch (_: RuntimeException) {
            null
        }
    }
}
