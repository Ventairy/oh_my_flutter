package dev.ventairy.oh_my_flutter

import android.annotation.SuppressLint
import android.app.Activity
import android.content.res.Resources
import android.graphics.Point
import android.os.Build
import android.view.Display
import android.view.RoundedCorner
import android.view.Surface
import android.view.WindowInsets
import androidx.annotation.ChecksSdkIntAtLeast
import androidx.annotation.RequiresApi
import dev.ventairy.oh_my_flutter.device_display.AndroidDeviceDisplayApi
import dev.ventairy.oh_my_flutter.device_display.AndroidDeviceDisplayCornerRadii
import dev.ventairy.oh_my_flutter.device_display.AndroidDeviceDisplayGeometry
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/** Reads exact or OEM-declared Android display corner radii. */
internal class DeviceDisplayHandler(
    private val sdkInt: Int = Build.VERSION.SDK_INT,
    private val rootWindowInsetsOperation: (Activity) -> WindowInsets? = {
        it.window.decorView.rootWindowInsets
    },
    private val windowedStateOperation: (Activity) -> Boolean = Companion::isWindowed,
    private val resourcesOperation: (Activity) -> Resources = Activity::getResources,
    private val displayOperation: (Activity) -> Display? = {
        it.window.decorView.display
    },
    private val displayIdOperation: (Display) -> Int = Display::getDisplayId,
    private val displaySizeOperation: (Display) -> DeviceDisplaySize? =
        Companion::displaySize,
    private val windowSizeOperation: (Activity) -> DeviceDisplaySize? =
        Companion::windowSize,
    private val resourceDimensionOperation: (Resources, String) -> Int =
        Companion::frameworkDimension,
    private val hasPerDisplayConfigOperation: (Resources) -> Boolean =
        Companion::hasPerDisplayConfig,
    private val displayScaleOperation: (Display) -> Double = {
        Companion.displayScale(it, displaySizeOperation(it))
    },
    private val displayRotationOperation: (Display) -> Int = Display::getRotation,
) : AndroidDeviceDisplayApi {
    private var activity: Activity? = null

    override fun getCornerRadii(
        geometry: AndroidDeviceDisplayGeometry,
    ): AndroidDeviceDisplayCornerRadii? {
        val currentActivity = activity ?: return null
        return try {
            if (!matchesGeometry(currentActivity, geometry)) return null
            if (windowedStateOperation(currentActivity)) return null
            if (supportsExactCornerRadii()) {
                exactCornerRadii(currentActivity)
                    ?: legacyCornerRadii(currentActivity)
            } else {
                legacyCornerRadii(currentActivity)
            }
        } catch (_: RuntimeException) {
            null
        }
    }

    /** Associates display queries with the current Flutter activity. */
    fun attachActivity(activity: Activity) {
        this.activity = activity
    }

    /** Stops display queries from using an activity that is no longer attached. */
    fun detachActivity() {
        activity = null
    }

    @ChecksSdkIntAtLeast(api = Build.VERSION_CODES.S)
    private fun supportsExactCornerRadii(): Boolean {
        return sdkInt >= Build.VERSION_CODES.S
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun exactCornerRadii(activity: Activity): AndroidDeviceDisplayCornerRadii? {
        val insets = rootWindowInsetsOperation(activity) ?: return null
        return AndroidDeviceDisplayCornerRadii(
            topLeft = insets.cornerRadius(RoundedCorner.POSITION_TOP_LEFT),
            topRight = insets.cornerRadius(RoundedCorner.POSITION_TOP_RIGHT),
            bottomRight = insets.cornerRadius(RoundedCorner.POSITION_BOTTOM_RIGHT),
            bottomLeft = insets.cornerRadius(RoundedCorner.POSITION_BOTTOM_LEFT),
        )
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun WindowInsets.cornerRadius(position: Int): Double {
        return getRoundedCorner(position)?.radius?.toDouble() ?: 0.0
    }

    private fun legacyCornerRadii(activity: Activity): AndroidDeviceDisplayCornerRadii? {
        if (windowedStateOperation(activity)) return null

        val display = displayOperation(activity) ?: return null
        if (displayIdOperation(display) != Display.DEFAULT_DISPLAY) return null

        val resources = resourcesOperation(activity)
        if (hasPerDisplayConfigOperation(resources)) return null
        val defaultRadius = resourceDimensionOperation(resources, DEFAULT_RADIUS_NAME)
        val topRadius = resourceDimensionOperation(resources, TOP_RADIUS_NAME)
        val bottomRadius = resourceDimensionOperation(resources, BOTTOM_RADIUS_NAME)
        if (defaultRadius <= 0 && topRadius <= 0 && bottomRadius <= 0) return null

        val scale = displayScaleOperation(display)
        if (!scale.isFinite() || scale <= 0) return null

        val resolvedTop = if (topRadius > 0) topRadius else defaultRadius
        val resolvedBottom = if (bottomRadius > 0) bottomRadius else defaultRadius
        if (resolvedTop <= 0 || resolvedBottom <= 0) return null

        val scaledTop = scaleRadius(resolvedTop, scale)
        val scaledBottom = scaleRadius(resolvedBottom, scale)
        if (scaledTop <= 0 || scaledBottom <= 0) return null
        return rotatedCornerRadii(
            topRadius = scaledTop,
            bottomRadius = scaledBottom,
            rotation = displayRotationOperation(display),
        )
    }

    private fun matchesGeometry(
        activity: Activity,
        geometry: AndroidDeviceDisplayGeometry,
    ): Boolean {
        val expectedValues = listOf(
            geometry.displayWidth,
            geometry.displayHeight,
            geometry.viewWidth,
            geometry.viewHeight,
        )
        if (expectedValues.any { !it.isFinite() || it <= 0 }) return false

        val display = displayOperation(activity) ?: return false
        val displaySize = displaySizeOperation(display) ?: return false
        val windowSize = windowSizeOperation(activity) ?: return false
        return dimensionsMatch(
            geometry.displayWidth,
            geometry.displayHeight,
            displaySize,
        ) && dimensionsMatch(
            geometry.viewWidth,
            geometry.viewHeight,
            windowSize,
        )
    }

    private fun dimensionsMatch(
        expectedWidth: Double,
        expectedHeight: Double,
        actual: DeviceDisplaySize,
    ): Boolean {
        return abs(expectedWidth - actual.width) <= GEOMETRY_TOLERANCE_PIXELS &&
            abs(expectedHeight - actual.height) <= GEOMETRY_TOLERANCE_PIXELS
    }

    private fun scaleRadius(radius: Int, scale: Double): Double {
        if (radius <= 0) return 0.0
        return (radius * scale + 0.5).toInt().toDouble()
    }

    private fun rotatedCornerRadii(
        topRadius: Double,
        bottomRadius: Double,
        rotation: Int,
    ): AndroidDeviceDisplayCornerRadii? {
        return when (rotation) {
            Surface.ROTATION_0 -> AndroidDeviceDisplayCornerRadii(
                topRadius,
                topRadius,
                bottomRadius,
                bottomRadius,
            )

            Surface.ROTATION_90 -> AndroidDeviceDisplayCornerRadii(
                topRadius,
                bottomRadius,
                bottomRadius,
                topRadius,
            )

            Surface.ROTATION_180 -> AndroidDeviceDisplayCornerRadii(
                bottomRadius,
                bottomRadius,
                topRadius,
                topRadius,
            )

            Surface.ROTATION_270 -> AndroidDeviceDisplayCornerRadii(
                bottomRadius,
                topRadius,
                topRadius,
                bottomRadius,
            )

            else -> null
        }
    }

    private companion object {
        const val DEFAULT_RADIUS_NAME = "rounded_corner_radius"
        const val TOP_RADIUS_NAME = "rounded_corner_radius_top"
        const val BOTTOM_RADIUS_NAME = "rounded_corner_radius_bottom"
        const val DISPLAY_UNIQUE_ID_ARRAY_NAME = "config_displayUniqueIdArray"
        const val GEOMETRY_TOLERANCE_PIXELS = 1.0

        fun isWindowed(activity: Activity): Boolean {
            if (activity.isInMultiWindowMode) return true
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
            return activity.isInPictureInPictureMode
        }

        // Android does not expose generated identifiers for these hidden OEM resources.
        @SuppressLint("DiscouragedApi")
        fun frameworkDimension(resources: Resources, name: String): Int {
            return try {
                val identifier = resources.getIdentifier(name, "dimen", "android")
                if (identifier == 0) 0 else resources.getDimensionPixelSize(identifier)
            } catch (_: RuntimeException) {
                0
            }
        }

        @Suppress("DEPRECATION")
        fun displaySize(display: Display): DeviceDisplaySize? {
            val size = Point()
            display.getRealSize(size)
            return DeviceDisplaySize(size.x, size.y)
                .takeIf { it.width > 0 && it.height > 0 }
        }

        fun windowSize(activity: Activity): DeviceDisplaySize? {
            val decorView = activity.window.decorView
            return DeviceDisplaySize(decorView.width, decorView.height)
                .takeIf { it.width > 0 && it.height > 0 }
        }

        @SuppressLint("DiscouragedApi")
        fun hasPerDisplayConfig(resources: Resources): Boolean {
            val identifier = resources.getIdentifier(
                DISPLAY_UNIQUE_ID_ARRAY_NAME,
                "array",
                "android",
            )
            return identifier != 0 && resources.getStringArray(identifier).isNotEmpty()
        }

        fun displayScale(
            display: Display,
            currentSize: DeviceDisplaySize?,
        ): Double {
            val maximumMode = display.supportedModes.maxByOrNull {
                it.physicalWidth
            } ?: return 1.0
            if (
                maximumMode.physicalWidth <= 0 ||
                maximumMode.physicalHeight <= 0 ||
                currentSize == null
            ) {
                return if (currentSize == null) Double.NaN else 1.0
            }
            val maximumShortSide = min(
                maximumMode.physicalWidth,
                maximumMode.physicalHeight,
            )
            val maximumLongSide = max(
                maximumMode.physicalWidth,
                maximumMode.physicalHeight,
            )
            val currentShortSide = min(currentSize.width, currentSize.height)
            val currentLongSide = max(currentSize.width, currentSize.height)
            return min(
                currentShortSide.toDouble() / maximumShortSide,
                currentLongSide.toDouble() / maximumLongSide,
            )
        }
    }
}
