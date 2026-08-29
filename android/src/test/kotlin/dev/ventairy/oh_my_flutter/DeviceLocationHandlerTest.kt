package dev.ventairy.oh_my_flutter

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.location.Address
import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.CancellationSignal
import android.provider.Settings
import java.io.IOException
import java.util.concurrent.Executor
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import org.mockito.ArgumentMatchers.anyInt
import org.mockito.ArgumentMatchers.anyString
import org.mockito.ArgumentCaptor
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
    fun `when reverse geocoding succeeds, it should map every address field`() {
        val nativeAddress = mock(Address::class.java)
        Mockito.`when`(nativeAddress.maxAddressLineIndex).thenReturn(1)
        Mockito.`when`(nativeAddress.getAddressLine(0)).thenReturn("Rua Harmonia, 797")
        Mockito.`when`(nativeAddress.getAddressLine(1)).thenReturn("São Paulo - SP")
        Mockito.`when`(nativeAddress.featureName).thenReturn("Edifício Harmonia")
        Mockito.`when`(nativeAddress.thoroughfare).thenReturn("Rua Harmonia")
        Mockito.`when`(nativeAddress.subThoroughfare).thenReturn("797")
        Mockito.`when`(nativeAddress.subLocality).thenReturn("Vila Madalena")
        Mockito.`when`(nativeAddress.subAdminArea).thenReturn("São Paulo")
        Mockito.`when`(nativeAddress.locality).thenReturn("São Paulo")
        Mockito.`when`(nativeAddress.adminArea).thenReturn("SP")
        Mockito.`when`(nativeAddress.postalCode).thenReturn("05435-001")
        Mockito.`when`(nativeAddress.countryName).thenReturn("Brasil")
        Mockito.`when`(nativeAddress.countryCode).thenReturn("br")
        var response: Result<AndroidDeviceLocationAddress>? = null
        val handler = handler(
            currentAddress = { _, _, _, _, callback ->
                callback(Result.success(nativeAddress))
            },
        )

        handler.getAddress(
            -23.556391,
            -46.844076,
            "pt-BR",
            DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS,
        ) { response = it }

        assertEquals(
            AndroidDeviceLocationAddress(
                formattedAddress = "Rua Harmonia, 797\nSão Paulo - SP",
                name = "Edifício Harmonia",
                street = "Rua Harmonia",
                streetNumber = "797",
                neighborhood = "Vila Madalena",
                district = "São Paulo",
                city = "São Paulo",
                state = "SP",
                postalCode = "05435-001",
                country = "Brasil",
                countryCode = "BR",
            ),
            response?.getOrNull(),
        )
    }

    @Test
    fun `when address lines have an excessive sparse index, it should inspect a bounded range`() {
        val nativeAddress = mock(Address::class.java)
        Mockito.`when`(nativeAddress.maxAddressLineIndex)
            .thenReturn(DeviceLocationHandler.MAX_ADDRESS_LINE_COUNT)
        Mockito.`when`(nativeAddress.getAddressLine(0)).thenReturn("Cupertino")
        Mockito.`when`(
            nativeAddress.getAddressLine(DeviceLocationHandler.MAX_ADDRESS_LINE_COUNT),
        ).thenReturn("Untrusted sparse line")
        var response: Result<AndroidDeviceLocationAddress>? = null
        val handler = handler(
            currentAddress = { _, _, _, _, callback ->
                callback(Result.success(nativeAddress))
            },
        )

        handler.getAddress(
            37.3317,
            -122.0301,
            null,
            DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS,
        ) { response = it }

        assertEquals("Cupertino", response?.getOrNull()?.formattedAddress)
    }

    @Test
    fun `when country codes are malformed, it should omit them`() {
        val returnedCountryCodes = listOf("1x", "ßx", "ß").map { countryCode ->
            val nativeAddress = mock(Address::class.java)
            Mockito.`when`(nativeAddress.maxAddressLineIndex).thenReturn(-1)
            Mockito.`when`(nativeAddress.locality).thenReturn("Cupertino")
            Mockito.`when`(nativeAddress.countryCode).thenReturn(countryCode)
            var response: Result<AndroidDeviceLocationAddress>? = null
            val handler = handler(
                currentAddress = { _, _, _, _, callback ->
                    callback(Result.success(nativeAddress))
                },
            )
            handler.getAddress(
                37.3317,
                -122.0301,
                null,
                DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS,
            ) { response = it }
            response?.getOrNull()?.countryCode
        }

        assertEquals(listOf(null, null, null), returnedCountryCodes)
    }

    @Test
    fun `when asynchronous address mapping throws, it should report operation unavailable`() {
        val nativeAddress = mock(Address::class.java)
        Mockito.`when`(nativeAddress.maxAddressLineIndex).thenThrow(
            IllegalStateException("malformed address"),
        )
        var nativeCallback: ((Result<Address?>) -> Unit)? = null
        var mainWork: Runnable? = null
        var response: Result<AndroidDeviceLocationAddress>? = null
        val handler = handler(
            currentAddress = { _, _, _, _, callback -> nativeCallback = callback },
            mainExecutor = Executor { work -> mainWork = work },
        )
        handler.getAddress(
            37.3317,
            -122.0301,
            null,
            DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS,
        ) { response = it }

        requireNotNull(nativeCallback).invoke(Result.success(nativeAddress))
        requireNotNull(mainWork).run()

        assertEquals(
            AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE,
            response.locationFailure,
        )
    }

    @Test
    fun `when reverse geocoding starts, it should forward coordinates and locale`() {
        var request: Triple<Double, Double, String?>? = null
        val nativeAddress = mock(Address::class.java)
        Mockito.`when`(nativeAddress.maxAddressLineIndex).thenReturn(-1)
        Mockito.`when`(nativeAddress.locality).thenReturn("Cupertino")
        val handler = handler(
            currentAddress = { latitude, longitude, locale, _, callback ->
                request = Triple(latitude, longitude, locale)
                callback(Result.success(nativeAddress))
            },
        )

        handler.getAddress(
            37.3317,
            -122.0301,
            "en-US",
            DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS,
        ) {}

        assertEquals(Triple(37.3317, -122.0301, "en-US"), request)
    }

    @Test
    fun `when address locales overlap, it should keep their native results independent`() {
        val callbacks = mutableMapOf<String, (Result<Address?>) -> Unit>()
        var portuguese: Result<AndroidDeviceLocationAddress>? = null
        var english: Result<AndroidDeviceLocationAddress>? = null
        val handler = handler(
            currentAddress = { _, _, locale, _, callback ->
                callbacks[requireNotNull(locale)] = callback
            },
        )
        handler.getAddress(
            0.0,
            0.0,
            "pt-BR",
            DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS,
        ) { portuguese = it }
        handler.getAddress(
            0.0,
            0.0,
            "en-US",
            DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS,
        ) { english = it }
        val portugueseAddress = mock(Address::class.java)
        Mockito.`when`(portugueseAddress.maxAddressLineIndex).thenReturn(-1)
        Mockito.`when`(portugueseAddress.locality).thenReturn("São Paulo")
        val englishAddress = mock(Address::class.java)
        Mockito.`when`(englishAddress.maxAddressLineIndex).thenReturn(-1)
        Mockito.`when`(englishAddress.locality).thenReturn("New York")

        requireNotNull(callbacks["en-US"]).invoke(Result.success(englishAddress))
        requireNotNull(callbacks["pt-BR"]).invoke(Result.success(portugueseAddress))

        assertEquals(
            "São Paulo" to "New York",
            portuguese?.getOrNull()?.city to english?.getOrNull()?.city,
        )
    }

    @Test
    fun `when Android is API 33 or newer, it should use asynchronous geocoding`() {
        val geocoder = mock(Geocoder::class.java)
        val nativeAddress = mock(Address::class.java)
        val listener = ArgumentCaptor.forClass(Geocoder.GeocodeListener::class.java)
        Mockito.doNothing().`when`(geocoder).getFromLocation(
            Mockito.eq(37.3317),
            Mockito.eq(-122.0301),
            Mockito.eq(1),
            listener.capture(),
        )
        var response: Result<Address?>? = null

        DeviceLocationHandler.requestModernAddress(
            geocoder,
            37.3317,
            -122.0301,
        ) { response = it }
        listener.value.onGeocode(mutableListOf(nativeAddress))

        assertEquals(nativeAddress, response?.getOrNull())
    }

    @Test
    fun `when Android routes API 33 geocoding, it should use the asynchronous path`() {
        val geocoder = mock(Geocoder::class.java)
        val nativeAddress = mock(Address::class.java)
        val listener = ArgumentCaptor.forClass(Geocoder.GeocodeListener::class.java)
        Mockito.doNothing().`when`(geocoder).getFromLocation(
            Mockito.eq(37.3317),
            Mockito.eq(-122.0301),
            Mockito.eq(1),
            listener.capture(),
        )
        var backgroundExecutions = 0
        var response: Result<Address?>? = null

        DeviceLocationHandler.requestAddress(
            context,
            37.3317,
            -122.0301,
            "en-US",
            Executor { command ->
                backgroundExecutions += 1
                command.run()
            },
            { response = it },
            sdkInt = Build.VERSION_CODES.TIRAMISU,
            geocoderFactory = { _, _ -> geocoder },
        )
        listener.value.onGeocode(mutableListOf(nativeAddress))

        assertEquals(nativeAddress to 0, response?.getOrNull() to backgroundExecutions)
    }

    @Test
    fun `when asynchronous geocoding reports a null error, it should return a safe failure`() {
        val geocoder = mock(Geocoder::class.java)
        val listener = ArgumentCaptor.forClass(Geocoder.GeocodeListener::class.java)
        Mockito.doNothing().`when`(geocoder).getFromLocation(
            Mockito.eq(37.3317),
            Mockito.eq(-122.0301),
            Mockito.eq(1),
            listener.capture(),
        )
        var response: Result<Address?>? = null

        DeviceLocationHandler.requestModernAddress(
            geocoder,
            37.3317,
            -122.0301,
        ) { response = it }
        listener.value.onError(null)

        assertEquals("Reverse geocoding failed.", response?.exceptionOrNull()?.message)
    }

    @Suppress("DEPRECATION")
    @Test
    fun `when Android is before API 33, it should geocode on the background executor`() {
        val geocoder = mock(Geocoder::class.java)
        val nativeAddress = mock(Address::class.java)
        Mockito.`when`(geocoder.getFromLocation(37.3317, -122.0301, 1))
            .thenReturn(listOf(nativeAddress))
        var backgroundExecutions = 0
        var response: Result<Address?>? = null

        DeviceLocationHandler.requestLegacyAddressOnExecutor(
            geocoder,
            37.3317,
            -122.0301,
            Executor { command ->
                backgroundExecutions += 1
                command.run()
            },
        ) { response = it }

        assertEquals(nativeAddress to 1, response?.getOrNull() to backgroundExecutions)
    }

    @Suppress("DEPRECATION")
    @Test
    fun `when Android routes pre API 33 geocoding, it should use the legacy path`() {
        val geocoder = mock(Geocoder::class.java)
        val nativeAddress = mock(Address::class.java)
        Mockito.`when`(geocoder.getFromLocation(37.3317, -122.0301, 1))
            .thenReturn(listOf(nativeAddress))
        var backgroundExecutions = 0
        var response: Result<Address?>? = null

        DeviceLocationHandler.requestAddress(
            context,
            37.3317,
            -122.0301,
            "en-US",
            Executor { command ->
                backgroundExecutions += 1
                command.run()
            },
            { response = it },
            sdkInt = Build.VERSION_CODES.TIRAMISU - 1,
            geocoderFactory = { _, _ -> geocoder },
        )

        assertEquals(nativeAddress to 1, response?.getOrNull() to backgroundExecutions)
    }

    @Test
    fun `when no geocoder is present, it should report operation unavailable`() {
        var response: Result<AndroidDeviceLocationAddress>? = null
        val handler = handler(geocoderPresent = { false })

        handler.getAddress(
            0.0,
            0.0,
            null,
            DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS,
        ) { response = it }

        assertEquals(
            AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE,
            response.locationFailure,
        )
    }

    @Test
    fun `when reverse geocoding returns no address, it should report operation unavailable`() {
        var response: Result<AndroidDeviceLocationAddress>? = null
        val handler = handler(
            currentAddress = { _, _, _, _, callback ->
                callback(Result.success(null))
            },
        )

        handler.getAddress(
            0.0,
            0.0,
            null,
            DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS,
        ) { response = it }

        assertEquals(
            AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE,
            response.locationFailure,
        )
    }

    @Test
    fun `when reverse geocoding returns blank fields, it should report operation unavailable`() {
        var response: Result<AndroidDeviceLocationAddress>? = null
        val nativeAddress = mock(Address::class.java)
        Mockito.`when`(nativeAddress.maxAddressLineIndex).thenReturn(-1)
        Mockito.`when`(nativeAddress.locality).thenReturn("   ")
        val handler = handler(
            currentAddress = { _, _, _, _, callback ->
                callback(Result.success(nativeAddress))
            },
        )

        handler.getAddress(
            0.0,
            0.0,
            null,
            DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS,
        ) { response = it }

        assertEquals(
            AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE,
            response.locationFailure,
        )
    }

    @Test
    fun `when reverse geocoding fails, it should report operation unavailable`() {
        var response: Result<AndroidDeviceLocationAddress>? = null
        val handler = handler(
            currentAddress = { _, _, _, _, callback ->
                callback(Result.failure(IOException("unavailable")))
            },
        )

        handler.getAddress(
            0.0,
            0.0,
            null,
            DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS,
        ) { response = it }

        assertEquals(
            AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE,
            response.locationFailure,
        )
    }

    @Test
    fun `when reverse geocoding never completes, it should time out once`() {
        var nativeCallback: ((Result<Address?>) -> Unit)? = null
        var timeout: (() -> Unit)? = null
        var callbackCount = 0
        var response: Result<AndroidDeviceLocationAddress>? = null
        val nativeAddress = mock(Address::class.java)
        Mockito.`when`(nativeAddress.maxAddressLineIndex).thenReturn(-1)
        Mockito.`when`(nativeAddress.locality).thenReturn("Cupertino")
        val handler = handler(
            currentAddress = { _, _, _, _, callback -> nativeCallback = callback },
            scheduleAddressTimeout = { _, onTimeout ->
                timeout = onTimeout
                {}
            },
        )
        handler.getAddress(
            37.3317,
            -122.0301,
            null,
            DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS,
        ) {
            callbackCount += 1
            response = it
        }

        requireNotNull(timeout).invoke()
        requireNotNull(nativeCallback).invoke(Result.success(nativeAddress))

        assertEquals(
            1 to AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE,
            callbackCount to response.locationFailure,
        )
    }

    @Test
    fun `when reverse geocoding completes, it should cancel its timeout`() {
        var timeoutCancellationCount = 0
        val nativeAddress = mock(Address::class.java)
        Mockito.`when`(nativeAddress.maxAddressLineIndex).thenReturn(-1)
        Mockito.`when`(nativeAddress.locality).thenReturn("Cupertino")
        val handler = handler(
            currentAddress = { _, _, _, _, callback ->
                callback(Result.success(nativeAddress))
            },
            scheduleAddressTimeout = { _, _ ->
                { timeoutCancellationCount += 1 }
            },
        )

        handler.getAddress(
            37.3317,
            -122.0301,
            null,
            DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS,
        ) {}

        assertEquals(1, timeoutCancellationCount)
    }

    @Test
    fun `when reverse geocoding starts, it should schedule the requested timeout`() {
        var scheduledTimeout: Long? = null
        val handler = handler(
            scheduleAddressTimeout = { timeout, _ ->
                scheduledTimeout = timeout
                {}
            },
        )

        handler.getAddress(
            37.3317,
            -122.0301,
            null,
            DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS,
        ) {}

        assertEquals(DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS, scheduledTimeout)
        handler.dispose()
    }

    @Test
    fun `when coordinates are invalid, it should not start reverse geocoding`() {
        var requestCount = 0
        val handler = handler(
            currentAddress = { _, _, _, _, _ -> requestCount += 1 },
        )

        handler.getAddress(
            Double.NaN,
            0.0,
            null,
            DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS,
        ) {}

        assertEquals(0, requestCount)
    }

    @Test
    fun `when the engine detaches during reverse geocoding, it should complete once`() {
        var nativeCallback: ((Result<Address?>) -> Unit)? = null
        var callbackCount = 0
        var timeoutCancellationCount = 0
        val handler = handler(
            currentAddress = { _, _, _, _, callback -> nativeCallback = callback },
            scheduleAddressTimeout = { _, _ ->
                { timeoutCancellationCount += 1 }
            },
        )
        handler.getAddress(
            0.0,
            0.0,
            null,
            DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS,
        ) { callbackCount += 1 }

        handler.dispose()
        nativeCallback?.invoke(Result.success(mock(Address::class.java)))

        assertEquals(1 to 1, callbackCount to timeoutCancellationCount)
    }

    @Test
    fun `when the activity detaches during reverse geocoding, it should complete once`() {
        var nativeCallback: ((Result<Address?>) -> Unit)? = null
        var callbackCount = 0
        var timeoutCancellationCount = 0
        val handler = handler(
            currentAddress = { _, _, _, _, callback -> nativeCallback = callback },
            scheduleAddressTimeout = { _, _ ->
                { timeoutCancellationCount += 1 }
            },
        )
        handler.attachActivity(mock(Activity::class.java))
        handler.getAddress(
            0.0,
            0.0,
            null,
            DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS,
        ) { callbackCount += 1 }

        handler.detachActivity()
        nativeCallback?.invoke(Result.success(mock(Address::class.java)))

        assertEquals(1 to 1, callbackCount to timeoutCancellationCount)
    }

    @Test
    fun `when activity configuration changes, it should preserve reverse geocoding`() {
        var nativeCallback: ((Result<Address?>) -> Unit)? = null
        var response: Result<AndroidDeviceLocationAddress>? = null
        val nativeAddress = mock(Address::class.java)
        Mockito.`when`(nativeAddress.maxAddressLineIndex).thenReturn(-1)
        Mockito.`when`(nativeAddress.locality).thenReturn("Cupertino")
        val handler = handler(
            currentAddress = { _, _, _, _, callback -> nativeCallback = callback },
        )
        handler.attachActivity(mock(Activity::class.java))
        handler.getAddress(
            37.3317,
            -122.0301,
            null,
            DeviceLocationHandler.ADDRESS_TIMEOUT_MILLISECONDS,
        ) { response = it }

        handler.detachActivityForConfigChanges()
        requireNotNull(nativeCallback).invoke(Result.success(nativeAddress))

        assertEquals("Cupertino", response?.getOrNull()?.city)
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
        geocoderPresent: () -> Boolean = { true },
        currentAddress: (
            Double,
            Double,
            String?,
            Executor,
            (Result<Address?>) -> Unit,
        ) -> Unit = { _, _, _, _, _ -> },
        mainExecutor: Executor = Executor(Runnable::run),
        scheduleAddressTimeout: (Long, () -> Unit) -> (() -> Unit) = { _, _ -> {} },
    ): DeviceLocationHandler {
        return DeviceLocationHandler(
            applicationContext = context,
            locationManager = locationManager,
            isLocationEnabledOperation = isLocationEnabled,
            mainExecutorOperation = { mainExecutor },
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
            geocoderPresentOperation = geocoderPresent,
            backgroundExecutor = Executor(Runnable::run),
            currentAddressOperation = currentAddress,
            scheduleAddressTimeoutOperation = scheduleAddressTimeout,
        )
    }
}
