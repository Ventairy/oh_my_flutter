package dev.ventairy.oh_my_flutter

import dev.ventairy.oh_my_flutter.device_display.AndroidDeviceDisplayApi
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
    private var deviceDisplayHandler: DeviceDisplayHandler? = null
    private var deviceLocationHandler: DeviceLocationHandler? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val displayHandler = DeviceDisplayHandler()
        val locationHandler = DeviceLocationHandler(binding.applicationContext)
        deviceDisplayHandler = displayHandler
        deviceLocationHandler = locationHandler
        AndroidDeviceDisplayApi.setUp(binding.binaryMessenger, displayHandler)
        AndroidDeviceLocationApi.setUp(binding.binaryMessenger, locationHandler)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        deviceDisplayHandler?.attachActivity(binding.activity)
        deviceLocationHandler?.attachActivity(binding.activity)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        deviceDisplayHandler?.detachActivity()
        deviceLocationHandler?.detachActivityForConfigChanges()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        deviceDisplayHandler?.detachActivity()
        deviceLocationHandler?.detachActivity()
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
        activityBinding?.removeRequestPermissionsResultListener(this)
        activityBinding = null
        deviceDisplayHandler?.detachActivity()
        deviceDisplayHandler = null
        deviceLocationHandler?.dispose()
        deviceLocationHandler = null
        AndroidDeviceDisplayApi.setUp(binding.binaryMessenger, null)
        AndroidDeviceLocationApi.setUp(binding.binaryMessenger, null)
    }
}
