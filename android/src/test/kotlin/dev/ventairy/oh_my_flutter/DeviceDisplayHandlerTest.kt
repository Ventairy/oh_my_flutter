package dev.ventairy.oh_my_flutter

import android.app.Activity
import android.content.res.Resources
import android.graphics.Point
import android.view.Display
import android.view.RoundedCorner
import android.view.Surface
import android.view.WindowInsets
import dev.ventairy.oh_my_flutter.device_display.DeviceDisplayCornerRadiiMessage
import dev.ventairy.oh_my_flutter.device_display.DeviceDisplayGeometryMessage
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import org.mockito.Mockito
import org.mockito.Mockito.mock

class DeviceDisplayHandlerTest {
    private lateinit var activity: Activity
    private lateinit var display: Display
    private lateinit var resources: Resources

    @BeforeTest
    fun setUp() {
        activity = mock(Activity::class.java)
        display = mock(Display::class.java)
        resources = mock(Resources::class.java)
    }

    @Test
    fun `when API 31 reports every rounded corner, it should preserve physical radii`() {
        val insets = mock(WindowInsets::class.java)
        val topLeft = corner(10)
        val topRight = corner(20)
        val bottomRight = corner(30)
        val bottomLeft = corner(40)
        Mockito.`when`(insets.getRoundedCorner(RoundedCorner.POSITION_TOP_LEFT))
            .thenReturn(topLeft)
        Mockito.`when`(insets.getRoundedCorner(RoundedCorner.POSITION_TOP_RIGHT))
            .thenReturn(topRight)
        Mockito.`when`(insets.getRoundedCorner(RoundedCorner.POSITION_BOTTOM_RIGHT))
            .thenReturn(bottomRight)
        Mockito.`when`(insets.getRoundedCorner(RoundedCorner.POSITION_BOTTOM_LEFT))
            .thenReturn(bottomLeft)

        val cornerRadii = handler(
            sdkInt = 31,
            rootWindowInsets = insets,
        ).getCornerRadii()

        assertEquals(
            DeviceDisplayCornerRadiiMessage(10.0, 20.0, 30.0, 40.0),
            cornerRadii,
        )
    }

    @Test
    fun `when API 31 reports no rounded corners, it should preserve authoritative zeros`() {
        val cornerRadii = handler(
            sdkInt = 31,
            rootWindowInsets = mock(WindowInsets::class.java),
            resourcesByName = mapOf("rounded_corner_radius" to 20),
        ).getCornerRadii()

        assertEquals(
            DeviceDisplayCornerRadiiMessage(0.0, 0.0, 0.0, 0.0),
            cornerRadii,
        )
    }

    @Test
    fun `when API 31 reports every corner for a partial app window, it should use exact evidence`() {
        val insets = mock(WindowInsets::class.java)
        val windowCorner = corner(10)
        Mockito.`when`(insets.getRoundedCorner(RoundedCorner.POSITION_TOP_LEFT))
            .thenReturn(windowCorner)
        Mockito.`when`(insets.getRoundedCorner(RoundedCorner.POSITION_TOP_RIGHT))
            .thenReturn(windowCorner)
        Mockito.`when`(insets.getRoundedCorner(RoundedCorner.POSITION_BOTTOM_RIGHT))
            .thenReturn(windowCorner)
        Mockito.`when`(insets.getRoundedCorner(RoundedCorner.POSITION_BOTTOM_LEFT))
            .thenReturn(windowCorner)
        val cornerRadii = handler(
            sdkInt = 31,
            rootWindowInsets = insets,
            resourcesByName = mapOf("rounded_corner_radius" to 20),
            windowSize = DeviceDisplaySize(700, 1600),
        ).getCornerRadii(
            DeviceDisplayGeometryMessage(780.0, 1688.0, 700.0, 1600.0),
        )

        assertEquals(
            DeviceDisplayCornerRadiiMessage(10.0, 10.0, 10.0, 10.0),
            cornerRadii,
        )
    }

    @Test
    fun `when API 31 omits a corner for a partial app window, it should use legacy evidence`() {
        val insets = mock(WindowInsets::class.java)
        val windowCorner = corner(10)
        Mockito.`when`(insets.getRoundedCorner(RoundedCorner.POSITION_TOP_LEFT))
            .thenReturn(windowCorner)
        Mockito.`when`(insets.getRoundedCorner(RoundedCorner.POSITION_TOP_RIGHT))
            .thenReturn(windowCorner)
        Mockito.`when`(insets.getRoundedCorner(RoundedCorner.POSITION_BOTTOM_RIGHT))
            .thenReturn(windowCorner)
        val cornerRadii = handler(
            sdkInt = 31,
            rootWindowInsets = insets,
            resourcesByName = mapOf("rounded_corner_radius" to 20),
            windowSize = DeviceDisplaySize(700, 1600),
        ).getCornerRadii(
            DeviceDisplayGeometryMessage(780.0, 1688.0, 700.0, 1600.0),
        )

        assertEquals(
            DeviceDisplayCornerRadiiMessage(20.0, 20.0, 20.0, 20.0),
            cornerRadii,
        )
    }

    @Test
    fun `when API 31 root insets are unavailable, it should use positive legacy evidence`() {
        val cornerRadii = handler(
            sdkInt = 31,
            resourcesByName = mapOf("rounded_corner_radius" to 20),
        ).getCornerRadii()

        assertEquals(
            DeviceDisplayCornerRadiiMessage(20.0, 20.0, 20.0, 20.0),
            cornerRadii,
        )
    }

    @Test
    fun `when API 31 exact insets exist in a windowed activity, it should reject window-relative evidence`() {
        val insets = mock(WindowInsets::class.java)
        val topLeft = corner(10)
        val topRight = corner(20)
        val bottomRight = corner(30)
        val bottomLeft = corner(40)
        Mockito.`when`(insets.getRoundedCorner(RoundedCorner.POSITION_TOP_LEFT))
            .thenReturn(topLeft)
        Mockito.`when`(insets.getRoundedCorner(RoundedCorner.POSITION_TOP_RIGHT))
            .thenReturn(topRight)
        Mockito.`when`(insets.getRoundedCorner(RoundedCorner.POSITION_BOTTOM_RIGHT))
            .thenReturn(bottomRight)
        Mockito.`when`(insets.getRoundedCorner(RoundedCorner.POSITION_BOTTOM_LEFT))
            .thenReturn(bottomLeft)

        val cornerRadii = handler(
            sdkInt = 31,
            rootWindowInsets = insets,
            windowed = true,
        ).getCornerRadii()

        assertNull(cornerRadii)
    }

    @Test
    fun `when API 31 exact insets are unavailable in a windowed activity, it should reject legacy evidence`() {
        val cornerRadii = handler(
            sdkInt = 31,
            resourcesByName = mapOf("rounded_corner_radius" to 20),
            windowed = true,
        ).getCornerRadii()

        assertNull(cornerRadii)
    }

    @Test
    fun `when API 31 exact insets exist on a non-default display, it should preserve them`() {
        val insets = mock(WindowInsets::class.java)
        val topLeft = corner(10)
        Mockito.`when`(insets.getRoundedCorner(RoundedCorner.POSITION_TOP_LEFT))
            .thenReturn(topLeft)

        val cornerRadii = handler(
            sdkInt = 31,
            rootWindowInsets = insets,
            displayId = Display.DEFAULT_DISPLAY + 1,
        ).getCornerRadii()

        assertEquals(
            DeviceDisplayCornerRadiiMessage(10.0, 0.0, 0.0, 0.0),
            cornerRadii,
        )
    }

    @Test
    fun `when API 31 exact insets are unavailable on a non-default display, it should reject legacy evidence`() {
        val cornerRadii = handler(
            sdkInt = 31,
            resourcesByName = mapOf("rounded_corner_radius" to 20),
            displayId = Display.DEFAULT_DISPLAY + 1,
        ).getCornerRadii()

        assertNull(cornerRadii)
    }

    @Test
    fun `when no activity is attached, it should return null`() {
        val cornerRadii = DeviceDisplayHandler(
            sdkInt = 30,
        ).getCornerRadii()

        assertNull(cornerRadii)
    }

    @Test
    fun `when a platform display operation fails, it should return null`() {
        val handler = DeviceDisplayHandler(
            sdkInt = 30,
            windowedStateOperation = { false },
            displayOperation = { throw IllegalStateException("display unavailable") },
        ).also { it.attachActivity(activity) }

        assertNull(handler.getCornerRadii())
    }

    @Test
    fun `when legacy resources have no positive evidence, it should return null`() {
        val cornerRadii = handler(
            sdkInt = 30,
            resourcesByName = mapOf(
                "rounded_corner_radius" to 0,
                "rounded_corner_radius_top" to 0,
                "rounded_corner_radius_bottom" to 0,
            ),
        ).getCornerRadii()

        assertNull(cornerRadii)
    }

    @Test
    fun `when a legacy activity is multi-window or picture-in-picture, it should reject display radii`() {
        val cornerRadii = handler(
            sdkInt = 30,
            resourcesByName = mapOf("rounded_corner_radius" to 20),
            windowed = true,
        ).getCornerRadii()

        assertNull(cornerRadii)
    }

    @Test
    fun `when a legacy activity uses a non-default display, it should not read main-display resources`() {
        val handler = DeviceDisplayHandler(
            sdkInt = 30,
            windowedStateOperation = { false },
            displayOperation = { display },
            displayIdOperation = { Display.DEFAULT_DISPLAY + 1 },
            displaySizeOperation = { DeviceDisplaySize(780, 1688) },
            windowSizeOperation = { DeviceDisplaySize(780, 1688) },
            resourcesOperation = {
                throw AssertionError("Main-display resources must not be read")
            },
        ).also { it.attachActivity(activity) }

        val cornerRadii = handler.getCornerRadii()

        assertNull(cornerRadii)
    }

    @Test
    fun `when legacy overrides are zero, it should use the default radius`() {
        val cornerRadii = handler(
            sdkInt = 30,
            resourcesByName = mapOf("rounded_corner_radius" to 20),
        ).getCornerRadii()

        assertEquals(
            DeviceDisplayCornerRadiiMessage(20.0, 20.0, 20.0, 20.0),
            cornerRadii,
        )
    }

    @Test
    fun `when legacy overrides are positive, it should preserve top and bottom radii`() {
        val cornerRadii = handler(
            sdkInt = 30,
            resourcesByName = mapOf(
                "rounded_corner_radius" to 20,
                "rounded_corner_radius_top" to 30,
                "rounded_corner_radius_bottom" to 40,
            ),
        ).getCornerRadii()

        assertEquals(
            DeviceDisplayCornerRadiiMessage(30.0, 30.0, 40.0, 40.0),
            cornerRadii,
        )
    }

    @Test
    fun `when framework resources provide radii, it should resolve Android dimensions by name`() {
        Mockito.`when`(
            resources.getIdentifier(
                "rounded_corner_radius",
                "dimen",
                "android",
            ),
        ).thenReturn(1)
        Mockito.`when`(
            resources.getIdentifier(
                "rounded_corner_radius_top",
                "dimen",
                "android",
            ),
        ).thenReturn(2)
        Mockito.`when`(
            resources.getIdentifier(
                "rounded_corner_radius_bottom",
                "dimen",
                "android",
            ),
        ).thenReturn(3)
        Mockito.`when`(resources.getDimensionPixelSize(1)).thenReturn(20)
        Mockito.`when`(resources.getDimensionPixelSize(2)).thenReturn(30)
        Mockito.`when`(resources.getDimensionPixelSize(3)).thenReturn(40)
        val handler = DeviceDisplayHandler(
            sdkInt = 30,
            resourcesOperation = { resources },
            displayOperation = { display },
            displaySizeOperation = { DeviceDisplaySize(780, 1688) },
            windowSizeOperation = { DeviceDisplaySize(780, 1688) },
            displayScaleOperation = { 1.0 },
            displayRotationOperation = { Surface.ROTATION_0 },
        ).also { it.attachActivity(activity) }

        val cornerRadii = handler.getCornerRadii()

        assertEquals(
            DeviceDisplayCornerRadiiMessage(30.0, 30.0, 40.0, 40.0),
            cornerRadii,
        )
    }

    @Test
    fun `when legacy geometry is incomplete, it should return null`() {
        val cornerRadii = handler(
            sdkInt = 30,
            resourcesByName = mapOf("rounded_corner_radius_top" to 30),
        ).getCornerRadii()

        assertNull(cornerRadii)
    }

    @Test
    fun `when per-display resources exist, it should reject global legacy radii`() {
        Mockito.`when`(
            resources.getIdentifier(
                "config_displayUniqueIdArray",
                "array",
                "android",
            ),
        ).thenReturn(4)
        Mockito.`when`(resources.getStringArray(4)).thenReturn(arrayOf("local:display"))
        Mockito.`when`(
            resources.getIdentifier(
                "rounded_corner_radius",
                "dimen",
                "android",
            ),
        ).thenReturn(1)
        Mockito.`when`(resources.getDimensionPixelSize(1)).thenReturn(20)
        val handler = DeviceDisplayHandler(
            sdkInt = 30,
            resourcesOperation = { resources },
            displayOperation = { display },
            displaySizeOperation = { DeviceDisplaySize(780, 1688) },
            windowSizeOperation = { DeviceDisplaySize(780, 1688) },
            displayScaleOperation = { 1.0 },
            displayRotationOperation = { Surface.ROTATION_0 },
        ).also { it.attachActivity(activity) }

        val cornerRadii = handler.getCornerRadii()

        assertNull(cornerRadii)
    }

    @Suppress("DEPRECATION")
    @Test
    fun `when display resolution is reduced, it should scale and round legacy radii`() {
        val currentMode = mode(width = 1440, height = 3200)
        Mockito.`when`(display.supportedModes)
            .thenReturn(arrayOf(currentMode))
        Mockito.doAnswer { invocation ->
            invocation.getArgument<Point>(0).apply {
                x = 720
                y = 1600
            }
            null
        }.`when`(display).getRealSize(Mockito.any(Point::class.java))
        val handler = DeviceDisplayHandler(
            sdkInt = 30,
            resourcesOperation = { resources },
            displayOperation = { display },
            windowSizeOperation = { DeviceDisplaySize(720, 1600) },
            resourceDimensionOperation = { _, name ->
                if (name == "rounded_corner_radius") 41 else 0
            },
            displayRotationOperation = { Surface.ROTATION_0 },
        ).also { it.attachActivity(activity) }

        val cornerRadii = handler.getCornerRadii(
            DeviceDisplayGeometryMessage(720.0, 1600.0, 720.0, 1600.0),
        )

        assertEquals(
            DeviceDisplayCornerRadiiMessage(21.0, 21.0, 21.0, 21.0),
            cornerRadii,
        )
    }

    @Test
    fun `when the requesting Flutter view does not match the Android window, it should return null`() {
        val handler = DeviceDisplayHandler(
            sdkInt = 30,
            windowedStateOperation = { false },
            resourcesOperation = { resources },
            displayOperation = { display },
            displaySizeOperation = { DeviceDisplaySize(780, 1688) },
            windowSizeOperation = { DeviceDisplaySize(700, 1600) },
            resourceDimensionOperation = { _, name ->
                if (name == "rounded_corner_radius") 20 else 0
            },
            displayScaleOperation = { 1.0 },
        ).also { it.attachActivity(activity) }

        val cornerRadii = handler.getCornerRadii(defaultGeometry)

        assertNull(cornerRadii)
    }

    @Test
    fun `when display rotation is 90 degrees, it should rotate legacy radii`() {
        val cornerRadii = handler(
            sdkInt = 30,
            resourcesByName = legacyTopAndBottom,
            rotation = Surface.ROTATION_90,
        ).getCornerRadii()

        assertEquals(
            DeviceDisplayCornerRadiiMessage(30.0, 40.0, 40.0, 30.0),
            cornerRadii,
        )
    }

    @Test
    fun `when display rotation is 180 degrees, it should rotate legacy radii`() {
        val cornerRadii = handler(
            sdkInt = 30,
            resourcesByName = legacyTopAndBottom,
            rotation = Surface.ROTATION_180,
        ).getCornerRadii()

        assertEquals(
            DeviceDisplayCornerRadiiMessage(40.0, 40.0, 30.0, 30.0),
            cornerRadii,
        )
    }

    @Test
    fun `when display rotation is 270 degrees, it should rotate legacy radii`() {
        val cornerRadii = handler(
            sdkInt = 30,
            resourcesByName = legacyTopAndBottom,
            rotation = Surface.ROTATION_270,
        ).getCornerRadii()

        assertEquals(
            DeviceDisplayCornerRadiiMessage(40.0, 30.0, 30.0, 40.0),
            cornerRadii,
        )
    }

    @Test
    fun `when the activity detaches, it should stop returning legacy radii`() {
        val handler = handler(
            sdkInt = 30,
            resourcesByName = mapOf("rounded_corner_radius" to 20),
        )

        handler.detachActivity()

        assertNull(handler.getCornerRadii())
    }

    private fun handler(
        sdkInt: Int,
        rootWindowInsets: WindowInsets? = null,
        resourcesByName: Map<String, Int> = emptyMap(),
        scale: Double = 1.0,
        rotation: Int = Surface.ROTATION_0,
        windowed: Boolean = false,
        displayId: Int = Display.DEFAULT_DISPLAY,
        windowSize: DeviceDisplaySize = DeviceDisplaySize(780, 1688),
    ): DeviceDisplayHandler {
        return DeviceDisplayHandler(
            sdkInt = sdkInt,
            rootWindowInsetsOperation = { rootWindowInsets },
            windowedStateOperation = { windowed },
            resourcesOperation = { resources },
            displayOperation = { display },
            displayIdOperation = { displayId },
            displaySizeOperation = { DeviceDisplaySize(780, 1688) },
            windowSizeOperation = { windowSize },
            resourceDimensionOperation = { _, name -> resourcesByName[name] ?: 0 },
            displayScaleOperation = { scale },
            displayRotationOperation = { rotation },
        ).also { it.attachActivity(activity) }
    }

    private fun corner(radius: Int): RoundedCorner {
        return mock(RoundedCorner::class.java).also {
            Mockito.`when`(it.radius).thenReturn(radius)
        }
    }

    private fun mode(width: Int, height: Int): Display.Mode {
        return mock(Display.Mode::class.java).also {
            Mockito.`when`(it.physicalWidth).thenReturn(width)
            Mockito.`when`(it.physicalHeight).thenReturn(height)
        }
    }

    private companion object {
        val defaultGeometry = DeviceDisplayGeometryMessage(
            780.0,
            1688.0,
            780.0,
            1688.0,
        )

        val legacyTopAndBottom = mapOf(
            "rounded_corner_radius_top" to 30,
            "rounded_corner_radius_bottom" to 40,
        )
    }

    private fun DeviceDisplayHandler.getCornerRadii(): DeviceDisplayCornerRadiiMessage? {
        return getCornerRadii(defaultGeometry)
    }
}
