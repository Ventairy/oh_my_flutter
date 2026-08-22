package dev.ventairy.oh_my_flutter

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.net.Uri
import android.os.CancellationSignal
import android.provider.Settings
import androidx.core.content.ContextCompat
import androidx.core.location.LocationListenerCompat
import androidx.core.location.LocationManagerCompat
import androidx.core.location.LocationRequestCompat
import java.util.concurrent.Executor

/** Owns Android foreground-location permissions and one-shot coordinate requests. */
internal class DeviceLocationHandler(
    private val applicationContext: Context,
    private val locationManager: LocationManager =
        applicationContext.getSystemService(Context.LOCATION_SERVICE) as LocationManager,
    private val isLocationEnabledOperation: (LocationManager) -> Boolean =
        LocationManagerCompat::isLocationEnabled,
    private val mainExecutorOperation: (Context) -> Executor =
        ContextCompat::getMainExecutor,
    private val checkPermissionOperation: (Context, String) -> Int =
        ContextCompat::checkSelfPermission,
    private val requestPermissionsOperation: (Activity, Array<String>, Int) -> Unit =
        { activity, permissions, requestCode ->
            activity.requestPermissions(permissions, requestCode)
        },
    private val shouldShowPermissionRationaleOperation: (Activity, String) -> Boolean =
        { activity, permission ->
            activity.shouldShowRequestPermissionRationale(permission)
        },
    private val cancellationSignalFactory: () -> CancellationSignal =
        ::CancellationSignal,
    private val openLocationSettingsOperation: (Context, String, String) -> Boolean =
        Companion::openLocationSettings,
    private val currentCoordinatesOperation: (
        LocationManager,
        String,
        CancellationSignal,
        Executor,
        (Location?) -> Unit,
    ) -> Unit = Companion::requestCurrentLocation,
) : AndroidDeviceLocationApi {
    private var activity: Activity? = null
    private var permissionCallback:
        ((Result<AndroidDeviceLocationPermissionStatus>) -> Unit)? = null
    private var requestedPermissions: Array<String>? = null
    private var permissionHadRationaleBeforeRequest = false
    private var coordinatesCallback:
        ((Result<AndroidDeviceCoordinates>) -> Unit)? = null
    private var cancellationSignal: CancellationSignal? = null

    override fun isServiceEnabled(): Boolean {
        return try {
            isLocationEnabledOperation(locationManager)
        } catch (error: RuntimeException) {
            throw locationError(
                AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE,
                error.message,
            )
        }
    }

    override fun checkPermission(): AndroidDeviceLocationPermissionStatus {
        val declaredPermissions = declaredLocationPermissions()
        if (!hasRequiredManifestConfiguration(declaredPermissions)) {
            throw locationError(
                AndroidDeviceLocationFailure.CONFIGURATION_MISSING,
                "ACCESS_COARSE_LOCATION is missing from the application manifest.",
            )
        }
        return permissionState()
    }

    override fun requestPermission(
        callback: (Result<AndroidDeviceLocationPermissionStatus>) -> Unit,
    ) {
        var isCompleted = false
        val complete: (Result<AndroidDeviceLocationPermissionStatus>) -> Unit = { result ->
            if (!isCompleted) {
                isCompleted = true
                callback(result)
            }
        }
        try {
            startPermissionRequest(complete)
        } catch (error: Exception) {
            if (permissionCallback === complete) clearPermissionRequest()
            if (!isCompleted) {
                complete.failure(
                    AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE,
                    error.message,
                )
            }
        }
    }

    private fun startPermissionRequest(
        callback: (Result<AndroidDeviceLocationPermissionStatus>) -> Unit,
    ) {
        val declaredPermissions = declaredLocationPermissions()
        if (!hasRequiredManifestConfiguration(declaredPermissions)) {
            callback.failure(
                AndroidDeviceLocationFailure.CONFIGURATION_MISSING,
                "ACCESS_COARSE_LOCATION is missing from the application manifest.",
            )
            return
        }
        if (hasForegroundPermission()) {
            callback(Result.success(AndroidDeviceLocationPermissionStatus.WHILE_IN_USE))
            return
        }
        val currentActivity = activity
        if (currentActivity == null) {
            callback.failure(
                AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE,
                "Foreground location requires an attached activity.",
            )
            return
        }
        if (permissionCallback != null) {
            callback.failure(
                AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE,
                "A location permission request is already active.",
            )
            return
        }

        val permissions = buildList {
            add(Manifest.permission.ACCESS_COARSE_LOCATION)
            if (Manifest.permission.ACCESS_FINE_LOCATION in declaredPermissions) {
                add(Manifest.permission.ACCESS_FINE_LOCATION)
            }
        }.toTypedArray()
        permissionCallback = callback
        requestedPermissions = permissions
        permissionHadRationaleBeforeRequest = canRequestPermissionAgain(permissions)
        requestPermissionsOperation(currentActivity, permissions, PERMISSION_REQUEST_CODE)
    }

    override fun getCurrentCoordinates(callback: (Result<AndroidDeviceCoordinates>) -> Unit) {
        var isCompleted = false
        val complete: (Result<AndroidDeviceCoordinates>) -> Unit = { result ->
            if (!isCompleted) {
                isCompleted = true
                callback(result)
            }
        }
        try {
            startCurrentCoordinates(complete)
        } catch (error: SecurityException) {
            if (coordinatesCallback === complete) clearCoordinatesRequest()
            if (!isCompleted) {
                complete.failure(
                    AndroidDeviceLocationFailure.PERMISSION_DENIED,
                    error.message,
                )
            }
        } catch (error: Exception) {
            if (coordinatesCallback === complete) clearCoordinatesRequest()
            if (!isCompleted) {
                complete.failure(
                    AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE,
                    error.message,
                )
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun startCurrentCoordinates(
        callback: (Result<AndroidDeviceCoordinates>) -> Unit,
    ) {
        if (!hasRequiredManifestConfiguration(declaredLocationPermissions())) {
            callback.failure(
                AndroidDeviceLocationFailure.CONFIGURATION_MISSING,
                "ACCESS_COARSE_LOCATION is missing from the application manifest.",
            )
            return
        }
        if (!isServiceEnabled()) {
            callback.failure(
                AndroidDeviceLocationFailure.SERVICES_DISABLED,
                "Location services are disabled.",
            )
            return
        }
        if (!hasForegroundPermission()) {
            callback.failure(
                AndroidDeviceLocationFailure.PERMISSION_DENIED,
                "Foreground location permission is not granted.",
            )
            return
        }
        if (coordinatesCallback != null) {
            callback.failure(
                AndroidDeviceLocationFailure.COORDINATES_UNAVAILABLE,
                "A coordinates request is already active.",
            )
            return
        }

        val provider = bestProvider()
        if (provider == null) {
            callback.failure(
                AndroidDeviceLocationFailure.COORDINATES_UNAVAILABLE,
                "No enabled location provider can supply coordinates.",
            )
            return
        }

        val signal = cancellationSignalFactory()
        coordinatesCallback = callback
        cancellationSignal = signal
        try {
            currentCoordinatesOperation(
                locationManager,
                provider,
                signal,
                mainExecutorOperation(applicationContext),
                ::completeCoordinates,
            )
        } catch (error: SecurityException) {
            clearCoordinatesRequest()
            callback.failure(
                AndroidDeviceLocationFailure.PERMISSION_DENIED,
                error.message,
            )
        } catch (error: RuntimeException) {
            clearCoordinatesRequest()
            callback.failure(
                AndroidDeviceLocationFailure.COORDINATES_UNAVAILABLE,
                error.message,
            )
        }
    }

    override fun openLocationSettings(): Boolean {
        return try {
            openLocationSettingsOperation(
                applicationContext,
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                "package:${applicationContext.packageName}",
            )
        } catch (error: Exception) {
            throw locationError(
                AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE,
                error.message,
            )
        }
    }

    fun attachActivity(activity: Activity) {
        this.activity = activity
    }

    fun detachActivityForConfigChanges() {
        activity = null
    }

    fun detachActivity() {
        activity = null
        failPermissionRequest("The activity was detached.")
        failCoordinatesRequest("The activity was detached.")
    }

    fun dispose() {
        activity = null
        failPermissionRequest("The Flutter engine was detached.")
        failCoordinatesRequest("The Flutter engine was detached.")
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val callback = permissionCallback ?: return false

        if (permissions.isEmpty()) {
            clearPermissionRequest()
            callback(Result.success(AndroidDeviceLocationPermissionStatus.DENIED))
            return true
        }

        val requested = requestedPermissions.orEmpty()
        if (permissions.none { it in requested }) return false

        val permissionGranted = permissions.indices.any { index ->
            permissions[index] in requested &&
                grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED
        }
        val permission = when {
            permissionGranted || hasForegroundPermission() ->
                AndroidDeviceLocationPermissionStatus.WHILE_IN_USE
            permissionHadRationaleBeforeRequest && !canRequestPermissionAgain(requested) ->
                AndroidDeviceLocationPermissionStatus.DENIED_FOREVER
            else -> AndroidDeviceLocationPermissionStatus.DENIED
        }
        clearPermissionRequest()
        callback(Result.success(permission))
        return true
    }

    private fun completeCoordinates(location: Location?) {
        val callback = coordinatesCallback ?: return
        clearCoordinatesRequest()
        if (location == null ||
            !location.latitude.isFinite() ||
            location.latitude !in -90.0..90.0 ||
            !location.longitude.isFinite() ||
            location.longitude !in -180.0..180.0 ||
            !location.accuracy.isFinite() ||
            location.accuracy < 0
        ) {
            callback.failure(
                AndroidDeviceLocationFailure.COORDINATES_UNAVAILABLE,
                "The device did not provide valid coordinates.",
            )
            return
        }
        callback(
            Result.success(
                AndroidDeviceCoordinates(
                    latitude = location.latitude,
                    longitude = location.longitude,
                    accuracy = location.accuracy.toDouble(),
                ),
            ),
        )
    }

    private fun bestProvider(): String? {
        return listOf(
            FUSED_PROVIDER,
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
        ).firstOrNull { provider ->
            try {
                locationManager.isProviderEnabled(provider)
            } catch (error: SecurityException) {
                throw error
            } catch (_: RuntimeException) {
                false
            }
        }
    }

    private fun permissionState(): AndroidDeviceLocationPermissionStatus {
        return if (hasForegroundPermission()) {
            AndroidDeviceLocationPermissionStatus.WHILE_IN_USE
        } else {
            AndroidDeviceLocationPermissionStatus.DENIED
        }
    }

    private fun canRequestPermissionAgain(permissions: Array<out String>): Boolean {
        val currentActivity = activity ?: return true
        return permissions.any { permission ->
            shouldShowPermissionRationaleOperation(currentActivity, permission)
        }
    }

    private fun hasForegroundPermission(): Boolean {
        return hasPermission(Manifest.permission.ACCESS_COARSE_LOCATION) ||
            hasPermission(Manifest.permission.ACCESS_FINE_LOCATION)
    }

    private fun hasPermission(permission: String): Boolean {
        return checkPermissionOperation(applicationContext, permission) ==
            PackageManager.PERMISSION_GRANTED
    }

    @Suppress("DEPRECATION")
    private fun declaredLocationPermissions(): Set<String> {
        val packageInfo =
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                applicationContext.packageManager.getPackageInfo(
                    applicationContext.packageName,
                    PackageManager.PackageInfoFlags.of(
                        PackageManager.GET_PERMISSIONS.toLong(),
                    ),
                )
            } else {
                applicationContext.packageManager.getPackageInfo(
                    applicationContext.packageName,
                    PackageManager.GET_PERMISSIONS,
                )
            }
        return packageInfo.requestedPermissions?.toSet().orEmpty()
    }

    private fun hasRequiredManifestConfiguration(permissions: Set<String>): Boolean {
        return Manifest.permission.ACCESS_COARSE_LOCATION in permissions
    }

    private fun failPermissionRequest(message: String) {
        val callback = permissionCallback ?: return
        clearPermissionRequest()
        callback.failure(AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE, message)
    }

    private fun clearPermissionRequest() {
        permissionCallback = null
        requestedPermissions = null
        permissionHadRationaleBeforeRequest = false
    }

    private fun failCoordinatesRequest(message: String) {
        val callback = coordinatesCallback ?: return
        clearCoordinatesRequest()
        callback.failure(AndroidDeviceLocationFailure.COORDINATES_UNAVAILABLE, message)
    }

    private fun clearCoordinatesRequest() {
        val signal = cancellationSignal
        cancellationSignal = null
        coordinatesCallback = null
        signal?.cancel()
    }

    private fun <T> ((Result<T>) -> Unit).failure(
        failure: AndroidDeviceLocationFailure,
        message: String?,
    ) {
        invoke(Result.failure(locationError(failure, message)))
    }

    private fun locationError(
        failure: AndroidDeviceLocationFailure,
        message: String?,
    ): FlutterError {
        val code = when (failure) {
            AndroidDeviceLocationFailure.SERVICES_DISABLED -> SERVICES_DISABLED
            AndroidDeviceLocationFailure.PERMISSION_DENIED -> PERMISSION_DENIED
            AndroidDeviceLocationFailure.PERMISSION_PERMANENTLY_DENIED ->
                PERMISSION_PERMANENTLY_DENIED
            AndroidDeviceLocationFailure.CONFIGURATION_MISSING -> CONFIGURATION_MISSING
            AndroidDeviceLocationFailure.OPERATION_UNAVAILABLE -> OPERATION_UNAVAILABLE
            AndroidDeviceLocationFailure.COORDINATES_UNAVAILABLE ->
                COORDINATES_UNAVAILABLE
        }
        return FlutterError(code, message, failure)
    }

    private companion object {
        @SuppressLint("MissingPermission")
        fun requestCurrentLocation(
            manager: LocationManager,
            provider: String,
            cancellationSignal: CancellationSignal,
            executor: Executor,
            callback: (Location?) -> Unit,
        ) {
            // getCurrentLocation may return a recent cached fix; request one new update instead.
            val listener = object : LocationListenerCompat {
                override fun onLocationChanged(location: Location) {
                    manager.removeUpdates(this)
                    callback(location)
                }

                override fun onProviderDisabled(disabledProvider: String) {
                    if (disabledProvider != provider) return
                    manager.removeUpdates(this)
                    callback(null)
                }
            }
            val request = LocationRequestCompat.Builder(0)
                .setMinUpdateIntervalMillis(0)
                .setQuality(LocationRequestCompat.QUALITY_HIGH_ACCURACY)
                .setMaxUpdates(1)
                .build()
            LocationManagerCompat.requestLocationUpdates(
                manager,
                provider,
                request,
                executor,
                listener,
            )
            cancellationSignal.setOnCancelListener {
                manager.removeUpdates(listener)
            }
        }

        fun openLocationSettings(
            context: Context,
            action: String,
            data: String,
        ): Boolean {
            val intent = Intent(action, Uri.parse(data)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(context.packageManager) == null) return false
            context.startActivity(intent)
            return true
        }

        const val PERMISSION_REQUEST_CODE = 7642
        const val SERVICES_DISABLED = "servicesDisabled"
        const val PERMISSION_DENIED = "permissionDenied"
        const val PERMISSION_PERMANENTLY_DENIED = "permissionPermanentlyDenied"
        const val CONFIGURATION_MISSING = "configurationMissing"
        const val OPERATION_UNAVAILABLE = "operationUnavailable"
        const val COORDINATES_UNAVAILABLE = "coordinatesUnavailable"
        const val FUSED_PROVIDER = "fused"
    }
}
