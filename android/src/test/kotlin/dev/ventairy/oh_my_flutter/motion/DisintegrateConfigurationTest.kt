package dev.ventairy.oh_my_flutter.motion

import kotlin.test.Test
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class DisintegrateConfigurationTest {
    @Test
    fun `when the marked surface reaches the pixel and axis limits, it should accept it`() {
        assertTrue(configuration(320, 2047).nativeGaussian)
    }

    @Test
    fun `when the marker row tips the output over the pixel budget, it should reject the dimensions`() {
        assertFailsWith<IllegalArgumentException> { configuration(640, 1024) }
    }

    @Test
    fun `when the marker row tips the output over the axis limit, it should reject the dimensions`() {
        assertFailsWith<IllegalArgumentException> { configuration(22, 2048) }
    }

    @Test
    fun `when the viewport is equal but the Gaussian mode changes, it should reject scene reuse`() {
        assertFalse(configuration(100, 100).matches(configuration(100, 100, nativeGaussian = false)))
    }

    @Test
    fun `when full-density blur uses managed Skia output, it should accept the mode`() {
        assertTrue(configuration(100, 100, skiaGaussian = true, fullDensityGaussian = true).fullDensityGaussian)
    }

    @Test
    fun `when full-density blur uses a disabled Gaussian, it should reject the request`() {
        assertFailsWith<IllegalArgumentException> {
            configuration(100, 100, nativeGaussian = false, skiaGaussian = true, fullDensityGaussian = true)
        }
    }

    @Test
    fun `when full-density blur uses the Impeller kernel, it should reject the request`() {
        assertFailsWith<IllegalArgumentException> { configuration(100, 100, fullDensityGaussian = true) }
    }

    @Test
    fun `when full-density blur uses a legacy texture, it should reject the request`() {
        assertFailsWith<IllegalArgumentException> {
            configuration(100, 100, skiaGaussian = true, legacyGaussian = true, fullDensityGaussian = true)
        }
    }

    @Test
    fun `when the full-density mode changes, it should reject scene reuse at the same viewport`() {
        val original = configuration(100, 100, skiaGaussian = true)
        assertFalse(original.matches(configuration(100, 100, skiaGaussian = true, fullDensityGaussian = true)))
    }

    private fun configuration(
        viewportWidth: Int,
        viewportHeight: Int,
        nativeGaussian: Boolean = true,
        skiaGaussian: Boolean = false,
        legacyGaussian: Boolean = false,
        fullDensityGaussian: Boolean = false,
    ) =
        DisintegrateConfiguration(
            mapOf(
                "width" to 2, "height" to 2, "viewportWidth" to viewportWidth,
                "viewportHeight" to viewportHeight, "nativeGaussian" to nativeGaussian,
                "skiaGaussian" to skiaGaussian, "legacyGaussian" to legacyGaussian, "fullDensityGaussian" to fullDensityGaussian,
                "originX" to 0, "originY" to 0, "scaleX" to 1, "scaleY" to 1,
                "pointPadding" to 2, "maximumParticleCount" to 4, "minimumCellSize" to 1,
                "seed" to 42, "geometryParameters" to DoubleArray(10),
                "vertexSource" to "unused", "fragmentSource" to "unused",
            ),
        )
}
