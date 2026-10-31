package dev.ventairy.oh_my_flutter

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorManager
import dev.ventairy.oh_my_flutter.device_accelerometer.DeviceAccelerometerPlatformSample
import dev.ventairy.oh_my_flutter.device_accelerometer.FlutterError
import dev.ventairy.oh_my_flutter.device_accelerometer.PigeonEventSink
import io.flutter.plugin.common.EventChannel
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import org.mockito.ArgumentCaptor
import org.mockito.Mockito.mock
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`

class DeviceAccelerometerHandlerTest {
    private val manager = mock(SensorManager::class.java)
    private val sensor = mock(Sensor::class.java)
    private val sink = mock(EventChannel.EventSink::class.java)
    private val handler = DeviceAccelerometerHandler(manager)

    init {
        `when`(manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)).thenReturn(sensor)
        `when`(manager.registerListener(handler, sensor, 200000, 0, null)).thenReturn(true)
        `when`(manager.registerListener(handler, sensor, 20000, 0, null)).thenReturn(true)
    }

    private fun listen() {
        handler.configure(200000)
        handler.onListen(null, PigeonEventSink(sink))
    }

    @Test
    fun `when only configuration is supplied, it should not activate hardware`() {
        handler.configure(200000)
        verify(manager, never()).registerListener(handler, sensor, 200000, 0, null)
    }

    @Test
    fun `when a sink is attached, it should request the configured interval`() {
        listen()
        verify(manager).registerListener(handler, sensor, 200000, 0, null)
    }

    @Test
    fun `when the interval changes, it should register the new interval`() {
        listen()
        handler.configure(20000)
        verify(manager).registerListener(handler, sensor, 20000, 0, null)
    }

    @Test
    fun `when configuration is cleared, it should unregister the listener`() {
        listen()
        handler.configure(null)
        verify(manager).unregisterListener(handler)
    }

    @Test
    fun `when the stream cancels, it should unregister the listener`() {
        listen()
        handler.onCancel(null)
        verify(manager).unregisterListener(handler)
    }

    @Test
    fun `when the engine detaches, it should unregister the listener`() {
        listen()
        handler.dispose()
        verify(manager).unregisterListener(handler)
    }

    @Test
    fun `when the device has no sensor, it should report unavailable`() {
        `when`(manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)).thenReturn(null)
        assertFalse(handler.isAvailable())
    }

    @Test
    fun `when missing hardware is configured, it should report sensorUnavailable`() {
        `when`(manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)).thenReturn(null)
        val error = assertFailsWith<FlutterError> { handler.configure(200000) }
        assertEquals("sensorUnavailable", error.code)
    }

    @Test
    fun `when system permission is denied, it should emit a permission failure`() {
        `when`(manager.registerListener(handler, sensor, 200000, 0, null)).thenThrow(SecurityException("denied"))
        listen()
        verify(sink).error("permissionDenied", "denied", null)
    }

    @Test
    fun `when registration fails, it should emit an operation failure`() {
        `when`(manager.registerListener(handler, sensor, 200000, 0, null)).thenReturn(false)
        listen()
        verify(sink).error("operationUnavailable", "Could not register accelerometer", null)
    }

    @Test
    fun `when native data arrives, it should preserve acceleration and convert nanoseconds to microseconds`() {
        listen()
        val event = mock(SensorEvent::class.java)
        SensorEvent::class.java.getField("values").set(event, floatArrayOf(1f, 2f, 3f))
        event.timestamp = 1234567890
        handler.onSensorChanged(event)
        val sample = ArgumentCaptor.forClass(DeviceAccelerometerPlatformSample::class.java)
        verify(sink).success(sample.capture())
        assertEquals(listOf(1.0, 2.0, 3.0, 1234567L), listOf(sample.value.x, sample.value.y, sample.value.z, sample.value.timestampMicroseconds))
    }

    @Test
    fun `when stale data arrives after disposal, it should ignore it`() {
        listen()
        handler.dispose()
        handler.onSensorChanged(mock(SensorEvent::class.java))
        verify(sink, never()).success(org.mockito.ArgumentMatchers.any())
    }
}
