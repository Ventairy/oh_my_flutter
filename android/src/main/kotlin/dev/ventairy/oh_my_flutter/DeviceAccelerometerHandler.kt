package dev.ventairy.oh_my_flutter

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import dev.ventairy.oh_my_flutter.device_accelerometer.DeviceAccelerometerHostApi
import dev.ventairy.oh_my_flutter.device_accelerometer.DeviceAccelerometerPlatformSample
import dev.ventairy.oh_my_flutter.device_accelerometer.DeviceAccelerometerSamplesStreamHandler
import dev.ventairy.oh_my_flutter.device_accelerometer.FlutterError
import dev.ventairy.oh_my_flutter.device_accelerometer.PigeonEventSink

/** Owns one engine's foreground accelerometer subscription. */
internal class DeviceAccelerometerHandler(
    private val manager: SensorManager?,
    private val callbackHandler: Handler? = null,
) : DeviceAccelerometerSamplesStreamHandler(), DeviceAccelerometerHostApi, SensorEventListener {
    constructor(context: Context) : this(
        context.getSystemService(SensorManager::class.java),
        Handler(Looper.getMainLooper()),
    )

    private var sink: PigeonEventSink<DeviceAccelerometerPlatformSample>? = null
    private var interval: Long? = null
    private var running = false
    private var disposed = false

    override fun isAvailable(): Boolean = !disposed && manager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null

    override fun configure(samplingIntervalMicroseconds: Long?) {
        if (disposed) throw FlutterError("operationUnavailable", "Accelerometer handler is detached")
        stop()
        interval = samplingIntervalMicroseconds
        if (samplingIntervalMicroseconds != null && !isAvailable()) {
            interval = null
            throw FlutterError("sensorUnavailable", "No accelerometer is available")
        }
        if (sink != null) start()
    }

    override fun onListen(p0: Any?, sink: PigeonEventSink<DeviceAccelerometerPlatformSample>) {
        stop()
        this.sink = sink
        try {
            start()
        } catch (error: FlutterError) {
            sink.error(error.code, error.message, null)
        }
    }

    override fun onCancel(p0: Any?) {
        stop()
        sink = null
    }

    private fun start() {
        val requested = interval ?: return
        if (disposed || sink == null) return
        val sensor = manager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            ?: throw FlutterError("sensorUnavailable", "No accelerometer is available")
        try {
            val enabled = manager.registerListener(
                this, sensor, requested.coerceIn(1, Int.MAX_VALUE.toLong()).toInt(), 0, callbackHandler,
            )
            if (!enabled) throw FlutterError("operationUnavailable", "Could not register accelerometer")
            running = true
        } catch (error: SecurityException) {
            throw FlutterError("permissionDenied", error.message)
        }
    }

    private fun stop() {
        if (running) manager?.unregisterListener(this)
        running = false
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (!running || disposed) return
        sink?.success(
            DeviceAccelerometerPlatformSample(
                x = event.values[0].toDouble(),
                y = event.values[1].toDouble(),
                z = event.values[2].toDouble(),
                timestampMicroseconds = event.timestamp / 1000,
            ),
        )
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    fun dispose() {
        stop()
        interval = null
        sink = null
        disposed = true
    }
}
