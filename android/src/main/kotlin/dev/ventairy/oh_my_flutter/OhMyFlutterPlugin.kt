package dev.ventairy.oh_my_flutter

import dev.ventairy.oh_my_flutter.device_accelerometer.DeviceAccelerometerHostApi
import dev.ventairy.oh_my_flutter.device_accelerometer.DeviceAccelerometerSamplesStreamHandler
import dev.ventairy.oh_my_flutter.device_accelerometer.DeviceAccelerometerPigeonMethodCodec
import io.flutter.plugin.common.EventChannel

import dev.ventairy.oh_my_flutter.device_display.DeviceDisplayHostApi
import dev.ventairy.oh_my_flutter.device_sim.DeviceSimHostApi
import dev.ventairy.oh_my_flutter.device_locale.DeviceLocaleHostApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

/** Registers the package's Android device capabilities with each Flutter engine. */
class OhMyFlutterPlugin :
    FlutterPlugin,
    ActivityAware,
    PluginRegistry.RequestPermissionsResultListener {
    private var activityBinding: ActivityPluginBinding? = null
    private var deviceAccelerometerHandler: DeviceAccelerometerHandler? = null
    private var deviceDisplayHandler: DeviceDisplayHandler? = null
    private var deviceLocationHandler: DeviceLocationHandler? = null
    private var nativeSelectableTextMenuHandler: NativeSelectableTextMenuHandler? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val accelerometerHandler = DeviceAccelerometerHandler(binding.applicationContext)
        deviceAccelerometerHandler = accelerometerHandler
        DeviceAccelerometerHostApi.setUp(binding.binaryMessenger, accelerometerHandler)
        DeviceAccelerometerSamplesStreamHandler.register(binding.binaryMessenger, accelerometerHandler)
        DeviceSimHostApi.setUp(binding.binaryMessenger, DeviceSimHandler(binding.applicationContext))
        DeviceLocaleHostApi.setUp(binding.binaryMessenger, DeviceLocaleHandler(binding.applicationContext))
        val displayHandler = DeviceDisplayHandler()
        val locationHandler = DeviceLocationHandler(binding.applicationContext)
        deviceDisplayHandler = displayHandler
        deviceLocationHandler = locationHandler
        DeviceDisplayHostApi.setUp(binding.binaryMessenger, displayHandler)
        AndroidDeviceLocationApi.setUp(binding.binaryMessenger, locationHandler)

        val selectionMenuHandler = NativeSelectableTextMenuHandler(binding.binaryMessenger)
        nativeSelectableTextMenuHandler = selectionMenuHandler
        NativeSelectableTextMenuHostApi.setUp(binding.binaryMessenger, selectionMenuHandler)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        deviceDisplayHandler?.attachActivity(binding.activity)
        deviceLocationHandler?.attachActivity(binding.activity)
        nativeSelectableTextMenuHandler?.attachActivity(binding.activity)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        deviceDisplayHandler?.detachActivity()
        deviceLocationHandler?.detachActivityForConfigChanges()
        nativeSelectableTextMenuHandler?.detachActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        deviceDisplayHandler?.detachActivity()
        deviceLocationHandler?.detachActivity()
        nativeSelectableTextMenuHandler?.detachActivity()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ): Boolean {
        return deviceLocationHandler?.onRequestPermissionsResult(
            requestCode,
            permissions,
            grantResults,
        ) ?: false
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        deviceAccelerometerHandler?.dispose()
        deviceAccelerometerHandler = null
        DeviceAccelerometerHostApi.setUp(binding.binaryMessenger, null)
        EventChannel(binding.binaryMessenger, "dev.flutter.pigeon.oh_my_flutter.DeviceAccelerometerEventApi.deviceAccelerometerSamples", DeviceAccelerometerPigeonMethodCodec).setStreamHandler(null)
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        deviceDisplayHandler?.detachActivity()
        deviceDisplayHandler = null
        deviceLocationHandler?.dispose()
        deviceLocationHandler = null
        DeviceSimHostApi.setUp(binding.binaryMessenger, null)
        DeviceLocaleHostApi.setUp(binding.binaryMessenger, null)
        DeviceDisplayHostApi.setUp(binding.binaryMessenger, null)
        AndroidDeviceLocationApi.setUp(binding.binaryMessenger, null)
        nativeSelectableTextMenuHandler?.dispose()
        nativeSelectableTextMenuHandler = null
        NativeSelectableTextMenuHostApi.setUp(binding.binaryMessenger, null)
    }
}
