package dev.ventairy.oh_my_flutter

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.CancellationSignal
import android.provider.Settings
import java.util.concurrent.Executor
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import org.mockito.ArgumentMatchers.anyInt
import org.mockito.ArgumentMatchers.anyString
import org.mockito.Mockito
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify

class DeviceLocationHandlerTest {
    private lateinit var context: Context
    private lateinit var packageManager: PackageManager
    private lateinit var packageInfo: PackageInfo
    private lateinit var locationManager: LocationManager
    private val grantedPermissions = mutableSetOf<String>()

    @BeforeTest
    fun setUp() {
        context = mock(Context::class.java)
        packageManager = mock(PackageManager::class.java)
        packageInfo = PackageInfo().apply {
            requestedPermissions = arrayOf(
                Manifest.permission.ACCESS_COARSE_LOCATION,
                Manifest.permission.ACCESS_FINE_LOCATION,
            )
        }
        locationManager = mock(LocationManager::class.java)
        grantedPermissions.clear()

        Mockito.`when`(context.packageManager).thenReturn(packageManager)
        Mockito.`when`(context.packageName).thenReturn("dev.ventairy.test")
        Mockito.`when`(packageManager.getPackageInfo(anyString(), anyInt()))
            .thenReturn(packageInfo)
    }

    @Test
    fun `when the service check fails, it should report operation unavailable`() {
        val handler = handler(
            isLocationEnabled = { throw RuntimeException("unavailable") },
        )

        val failure = runCatching { handler.isServiceEnabled() }.exceptionOrNull()

        assertEquals(AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE, failure.locationFailure)
    }

    @Test
    fun `when coarse permission is not declared, it should report missing configuration`() {
        packageInfo.requestedPermissions = arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)

        val error = runCatching { handler().checkPermission() }.exceptionOrNull()

        assertEquals(
            AndroidDeviceLocationFailure.CONFIGURATION_MISSING,
            error.locationFailure,
        )
    }

    @Test
    fun `when coarse permission is granted, it should report while in use`() {
        grantPermission(Manifest.permission.ACCESS_COARSE_LOCATION)

        val permission = handler().checkPermission()

        assertEquals(AndroidDeviceLocationPermissionStatus.WHILE_IN_USE, permission)
    }

    @Test
    fun `when only coarse is declared, it should request only coarse permission`() {
        packageInfo.requestedPermissions = arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION)
        val activity = mock(Activity::class.java)
        var requestedPermissions: Array<String>? = null
        val handler = handler(
            requestPermissions = { _, permissions, _ ->
                requestedPermissions = permissions
            },
        ).also { it.attachActivity(activity) }

        handler.requestPermission {}

        assertContentEquals(
            arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION),
            requestedPermissions,
        )
    }

    @Test
    fun `when fine is declared, it should request coarse and fine together`() {
        val activity = mock(Activity::class.java)
        var requestedPermissions: Array<String>? = null
        val handler = handler(
            requestPermissions = { _, permissions, _ ->
                requestedPermissions = permissions
            },
        ).also { it.attachActivity(activity) }

        handler.requestPermission {}

        assertContentEquals(
            arrayOf(
                Manifest.permission.ACCESS_COARSE_LOCATION,
                Manifest.permission.ACCESS_FINE_LOCATION,
            ),
            requestedPermissions,
        )
    }

    @Test
    fun `when package lookup fails, it should fail a permission request once`() {
        Mockito.`when`(packageManager.getPackageInfo(anyString(), anyInt()))
            .thenThrow(RuntimeException("unavailable"))
        var callbackCount = 0
        var response: Result<AndroidDeviceLocationPermissionStatus>? = null

        handler().requestPermission {
            callbackCount += 1
            response = it
        }

        assertEquals(
            1 to AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE,
            callbackCount to response.locationFailure,
        )
    }

    @Test
    fun `when launching permission UI fails, it should fail the request once`() {
        val activity = mock(Activity::class.java)
        var callbackCount = 0
        var response: Result<AndroidDeviceLocationPermissionStatus>? = null
        val handler = handler(
            requestPermissions = { _, _, _ -> throw RuntimeException("unavailable") },
        ).also { it.attachActivity(activity) }

        handler.requestPermission {
            callbackCount += 1
            response = it
        }

        assertEquals(
            1 to AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE,
            callbackCount to response.locationFailure,
        )
    }

    @Test
    fun `when a permission request is interrupted, it should report denied`() {
        var response: Result<AndroidDeviceLocationPermissionStatus>? = null
        val handler = requestedPermissionHandler { response = it }

        handler.onRequestPermissionsResult(
            7642,
            emptyArray(),
            intArrayOf(PackageManager.PERMISSION_DENIED),
        )

        assertEquals(AndroidDeviceLocationPermissionStatus.DENIED, response?.getOrNull())
    }

    @Test
    fun `when another callback shares the request code, it should not consume it`() {
        val handler = requestedPermissionHandler()

        val consumed = handler.onRequestPermissionsResult(
            7642,
            arrayOf(Manifest.permission.CAMERA),
            intArrayOf(PackageManager.PERMISSION_DENIED),
        )

        assertFalse(consumed)
    }

    @Test
    fun `when denial can be requested again, it should report denied`() {
        var response: Result<AndroidDeviceLocationPermissionStatus>? = null
        val handler = requestedPermissionHandler(
            canRequestPermissionAgain = true,
            callback = { response = it },
        )

        handler.onRequestPermissionsResult(
            7642,
            arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION),
            intArrayOf(PackageManager.PERMISSION_DENIED),
        )

        assertEquals(AndroidDeviceLocationPermissionStatus.DENIED, response?.getOrNull())
    }

    @Test
    fun `when the first request is denied without rationale, it should report denied`() {
        var response: Result<AndroidDeviceLocationPermissionStatus>? = null
        val handler = requestedPermissionHandler { response = it }

        handler.onRequestPermissionsResult(
            7642,
            arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION),
            intArrayOf(PackageManager.PERMISSION_DENIED),
        )

        assertEquals(AndroidDeviceLocationPermissionStatus.DENIED, response?.getOrNull())
    }

    @Test
    fun `when a prior denial loses its rationale, it should report denied forever`() {
        var canRequestPermissionAgain = true
        var response: Result<AndroidDeviceLocationPermissionStatus>? = null
        val activity = mock(Activity::class.java)
        val handler = handler(
            shouldShowPermissionRationale = { _, _ -> canRequestPermissionAgain },
        ).also {
            it.attachActivity(activity)
            it.requestPermission { result -> response = result }
        }
        canRequestPermissionAgain = false

        handler.onRequestPermissionsResult(
            7642,
            arrayOf(Manifest.permission.ACCESS_COARSE_LOCATION),
            intArrayOf(PackageManager.PERMISSION_DENIED),
        )

        assertEquals(
            AndroidDeviceLocationPermissionStatus.DENIED_FOREVER,
            response?.getOrNull(),
        )
    }

    @Test
    fun `when approximate permission is granted, it should report while in use`() {
        var response: Result<AndroidDeviceLocationPermissionStatus>? = null
        val handler = requestedPermissionHandler { response = it }

        handler.onRequestPermissionsResult(
            7642,
            arrayOf(
                Manifest.permission.ACCESS_COARSE_LOCATION,
                Manifest.permission.ACCESS_FINE_LOCATION,
            ),
            intArrayOf(
                PackageManager.PERMISSION_GRANTED,
                PackageManager.PERMISSION_DENIED,
            ),
        )

        assertEquals(
            AndroidDeviceLocationPermissionStatus.WHILE_IN_USE,
            response?.getOrNull(),
        )
    }

    @Test
    fun `when activity configuration changes, it should preserve a permission request`() {
        var response: Result<AndroidDeviceLocationPermissionStatus>? = null
        val handler = requestedPermissionHandler { response = it }

        handler.detachActivityForConfigChanges()

        assertNull(response)
    }

    @Test
    fun `when activity detaches permanently, it should fail a permission request`() {
        var response: Result<AndroidDeviceLocationPermissionStatus>? = null
        val handler = requestedPermissionHandler { response = it }

        handler.detachActivity()

        assertEquals(
            AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE,
            response.locationFailure,
        )
    }

    @Test
    fun `when services are disabled, it should fail a coordinates request`() {
        grantPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        var response: Result<AndroidDeviceCoordinates>? = null
        val handler = handler(isLocationEnabled = { false })

        handler.getCurrentCoordinates { response = it }

        assertEquals(
            AndroidDeviceLocationFailure.SERVICES_DISABLED,
            response.locationFailure,
        )
    }

    @Test
    fun `when permission is denied, it should fail a coordinates request`() {
        var response: Result<AndroidDeviceCoordinates>? = null

        handler().getCurrentCoordinates { response = it }

        assertEquals(
            AndroidDeviceLocationFailure.PERMISSION_DENIED,
            response.locationFailure,
        )
    }

    @Test
    fun `when package lookup fails, it should fail a coordinates request once`() {
        Mockito.`when`(packageManager.getPackageInfo(anyString(), anyInt()))
            .thenThrow(RuntimeException("unavailable"))
        var callbackCount = 0
        var response: Result<AndroidDeviceCoordinates>? = null

        handler().getCurrentCoordinates {
            callbackCount += 1
            response = it
        }

        assertEquals(
            1 to AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE,
            callbackCount to response.locationFailure,
        )
    }

    @Test
    fun `when permission is revoked during provider lookup, it should report denied`() {
        grantPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        Mockito.`when`(locationManager.isProviderEnabled(anyString()))
            .thenThrow(SecurityException("revoked"))
        var response: Result<AndroidDeviceCoordinates>? = null

        handler().getCurrentCoordinates { response = it }

        assertEquals(
            AndroidDeviceLocationFailure.PERMISSION_DENIED,
            response.locationFailure,
        )
    }

    @Test
    fun `when fused location is enabled, it should prefer the fused provider`() {
        grantPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        Mockito.`when`(locationManager.isProviderEnabled("fused"))
            .thenReturn(true)
        var provider: String? = null
        val handler = handler(
            currentCoordinates = { _, selectedProvider, _, _, callback ->
                provider = selectedProvider
                callback(null)
            },
        )

        handler.getCurrentCoordinates {}

        assertEquals("fused", provider)
    }

    @Test
    fun `when approximate access has only GPS, it should use the GPS provider`() {
        grantPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        Mockito.`when`(locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER))
            .thenReturn(true)
        var provider: String? = null
        val handler = handler(
            currentCoordinates = { _, selectedProvider, _, _, callback ->
                provider = selectedProvider
                callback(null)
            },
        )

        handler.getCurrentCoordinates {}

        assertEquals(LocationManager.GPS_PROVIDER, provider)
    }

    @Test
    fun `when a valid location arrives, it should return its coordinates`() {
        grantPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        Mockito.`when`(locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER))
            .thenReturn(true)
        val location = mock(Location::class.java)
        Mockito.`when`(location.latitude).thenReturn(-23.556391)
        Mockito.`when`(location.longitude).thenReturn(-46.844076)
        Mockito.`when`(location.accuracy).thenReturn(8.5f)
        var response: Result<AndroidDeviceCoordinates>? = null
        val handler = handler(
            currentCoordinates = { _, _, _, _, callback -> callback(location) },
        )

        handler.getCurrentCoordinates { response = it }

        assertEquals(
            AndroidDeviceCoordinates(
                latitude = -23.556391,
                longitude = -46.844076,
                accuracy = 8.5,
            ),
            response?.getOrNull(),
        )
    }

    @Test
    fun `when native coordinates are invalid, it should report unavailable`() {
        grantPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        Mockito.`when`(locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER))
            .thenReturn(true)
        val location = mock(Location::class.java)
        Mockito.`when`(location.latitude).thenReturn(Double.NaN)
        var response: Result<AndroidDeviceCoordinates>? = null
        val handler = handler(
            currentCoordinates = { _, _, _, _, callback -> callback(location) },
        )

        handler.getCurrentCoordinates { response = it }

        assertEquals(
            AndroidDeviceLocationFailure.COORDINATES_UNAVAILABLE,
            response.locationFailure,
        )
    }

    @Test
    fun `when permission is revoked during acquisition, it should report denied`() {
        grantPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        Mockito.`when`(locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER))
            .thenReturn(true)
        var response: Result<AndroidDeviceCoordinates>? = null
        val handler = handler(
            currentCoordinates = { _, _, _, _, _ ->
                throw SecurityException("revoked")
            },
        )

        handler.getCurrentCoordinates { response = it }

        assertEquals(
            AndroidDeviceLocationFailure.PERMISSION_DENIED,
            response.locationFailure,
        )
    }

    @Test
    fun `when native acquisition fails, it should report coordinates unavailable`() {
        grantPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        Mockito.`when`(locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER))
            .thenReturn(true)
        var response: Result<AndroidDeviceCoordinates>? = null
        val handler = handler(
            currentCoordinates = { _, _, _, _, _ ->
                throw IllegalStateException("unavailable")
            },
        )

        handler.getCurrentCoordinates { response = it }

        assertEquals(
            AndroidDeviceLocationFailure.COORDINATES_UNAVAILABLE,
            response.locationFailure,
        )
    }

    @Test
    fun `when no provider is enabled, it should report unavailable`() {
        grantPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        var response: Result<AndroidDeviceCoordinates>? = null

        handler().getCurrentCoordinates { response = it }

        assertEquals(
            AndroidDeviceLocationFailure.COORDINATES_UNAVAILABLE,
            response.locationFailure,
        )
    }

    @Test
    fun `when the engine detaches during acquisition, it should cancel the request`() {
        grantPermission(Manifest.permission.ACCESS_COARSE_LOCATION)
        Mockito.`when`(locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER))
            .thenReturn(true)
        val cancellationSignal = mock(CancellationSignal::class.java)
        val handler = handler(
            cancellationSignalFactory = { cancellationSignal },
        )
        handler.getCurrentCoordinates {}

        handler.dispose()

        verify(cancellationSignal).cancel()
    }

    @Test
    fun `when location settings open, it should target this application's details`() {
        var launch: Pair<String, String>? = null
        val handler = handler(
            openLocationSettings = { _, action, data ->
                launch = action to data
                true
            },
        )

        val opened = handler.openLocationSettings()

        assertEquals(
            Triple(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                "package:dev.ventairy.test",
                true,
            ),
            Triple(
                launch?.first,
                launch?.second,
                opened,
            ),
        )
    }

    @Test
    fun `when location settings cannot open, it should return false`() {
        val handler = handler(openLocationSettings = { _, _, _ -> false })

        assertFalse(handler.openLocationSettings())
    }

    @Test
    fun `when location settings launch fails, it should report operation unavailable`() {
        val handler = handler(
            openLocationSettings = { _, _, _ -> error("launch failed") },
        )

        val failure = runCatching { handler.openLocationSettings() }.exceptionOrNull()

        assertEquals(AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE, failure.locationFailure)
    }

    private fun requestedPermissionHandler(
        activity: Activity = mock(Activity::class.java),
        canRequestPermissionAgain: Boolean = false,
        callback: (Result<AndroidDeviceLocationPermissionStatus>) -> Unit = {},
    ): DeviceLocationHandler {
        return handler(
            shouldShowPermissionRationale = { _, _ -> canRequestPermissionAgain },
        ).also {
            it.attachActivity(activity)
            it.requestPermission(callback)
        }
    }

    private fun grantPermission(permission: String) {
        grantedPermissions += permission
    }

    private val Throwable?.locationFailure: AndroidDeviceLocationFailure?
        get() = (this as? FlutterError)?.details as? AndroidDeviceLocationFailure

    private val Result<*>?.locationFailure: AndroidDeviceLocationFailure?
        get() = this?.exceptionOrNull().locationFailure

    private fun handler(
        isLocationEnabled: (LocationManager) -> Boolean = { true },
        requestPermissions: (Activity, Array<String>, Int) -> Unit = { _, _, _ -> },
        shouldShowPermissionRationale: (Activity, String) -> Boolean = { _, _ -> false },
        cancellationSignalFactory: () -> CancellationSignal = {
            mock(CancellationSignal::class.java)
        },
        openLocationSettings: (Context, String, String) -> Boolean = { _, _, _ -> true },
        currentCoordinates: (
            LocationManager,
            String,
            CancellationSignal,
            Executor,
            (Location?) -> Unit,
        ) -> Unit = { _, _, _, _, _ -> },
    ): DeviceLocationHandler {
        return DeviceLocationHandler(
            applicationContext = context,
            locationManager = locationManager,
            isLocationEnabledOperation = isLocationEnabled,
            mainExecutorOperation = { Executor(Runnable::run) },
            checkPermissionOperation = { _, permission ->
                if (permission in grantedPermissions) {
                    PackageManager.PERMISSION_GRANTED
                } else {
                    PackageManager.PERMISSION_DENIED
                }
            },
            requestPermissionsOperation = requestPermissions,
            shouldShowPermissionRationaleOperation = shouldShowPermissionRationale,
            cancellationSignalFactory = cancellationSignalFactory,
            openLocationSettingsOperation = openLocationSettings,
            currentCoordinatesOperation = currentCoordinates,
        )
    }
}
