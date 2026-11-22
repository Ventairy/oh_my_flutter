package dev.ventairy.oh_my_flutter.motion

import android.opengl.GLES20
import kotlin.test.Test
import kotlin.test.assertEquals
import org.mockito.Mockito.mockStatic
import org.mockito.stubbing.Answer

class ParticleRendererTest {
    private val renderer = createRenderer()

    private fun createRenderer(nativeGaussian: Boolean = false) = ParticleRenderer(
        DisintegrateConfiguration(
            mapOf(
                "width" to 2, "height" to 2, "viewportWidth" to 22, "viewportHeight" to 10,
                "originX" to 0, "originY" to 0, "scaleX" to 1, "scaleY" to 1,
                "pointPadding" to 2, "maximumParticleCount" to 4, "minimumCellSize" to 1,
                "seed" to 42, "geometryParameters" to DoubleArray(10),
                "vertexSource" to "unused", "fragmentSource" to "unused",
                "nativeGaussian" to nativeGaussian,
            ),
        ),
    )

    @Test
    fun `when consecutive probe pixels have the same color, it should clear them together`() {
        assertEquals(
            listOf(
                ProbeClear(0..0, 10..10, listOf(1f, 0f, 0f, 1f)),
                ProbeClear(1..21, 10..10, listOf(0f, 0f, 0f, 1f)),
            ),
            probeClears(1L),
        )
    }

    @Test
    fun `when a probe carries a signed handle, it should preserve every bit and opaque alpha`() {
        val handles = listOf(0L, 1L, Long.MAX_VALUE, Long.MIN_VALUE, -1L, -0x123456789ABCDEFL)
        val expected = handles.associateWith { handle ->
            List(22) { pixel ->
                val bit = 3 * pixel
                val rgb = List(3) { channel ->
                    if (bit + channel < 64 && (handle and (1L shl (bit + channel))) != 0L) 1f else 0f
                }
                rgb + 1f
            }
        }

        val actual = handles.associateWith { handle ->
            val clears = probeClears(handle)
            List(22) { pixel -> clears.single { pixel in it.columns && it.rows == 10..10 }.rgba }
        }

        assertEquals(expected, actual)
    }

    @Test
    fun `when Gaussian frame parameters are invalid, it should reject them before drawing`() {
        val gaussian = createRenderer(nativeGaussian = true)
        val invalidSigmas = listOf(
            4.0 to 0.0, 0.0 to 4.0, -1.0 to 4.0, 4.0 to Double.MAX_VALUE, Double.NaN to 4.0,
        ).map { (raster, display) ->
            DoubleArray(16).apply {
                this[14] = raster
                this[15] = display
            }
        }
        val invalid = listOf(14, 15, 17).map(::DoubleArray) + invalidSigmas
        val rejected = invalid.count { frame ->
            runCatching { gaussian.setFrame(frame) }.exceptionOrNull() is IllegalArgumentException
        }

        assertEquals(invalid.size, rejected)
    }

    @Test
    fun `when particle poses advance or replay, it should upload only changed shader settings`() {
        val first = doubleArrayOf(0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, -.5, .5, 1.0)
        val moving = first.copyOf().apply { this[0] = .32 }
        val prefix = moving.copyOf().apply {
            this[1] = .8
            this[2] = .6
        }
        val suffix = prefix.copyOf().apply {
            this[5] = .6
            this[6] = -.8
            this[7] = .25
            this[8] = .5
        }
        val opacity = suffix.copyOf().apply {
            this[9] = .375
            this[10] = .63
        }
        val direction = opacity.copyOf().apply {
            this[11] = .35
            this[12] = .94
        }
        val equivalent = direction.copyOf().apply { this[1] = Math.nextUp(.8) }
        val signedZero = equivalent.copyOf().apply { this[3] = -0.0 }
        val replay = signedZero.copyOf().apply { this[0] = 0.0 }
        val frames = listOf(first, moving, prefix, suffix, opacity, direction, equivalent, signedZero, replay, first)

        val expectedBits = frames.map { frame -> frame.drop(1).map { it.toFloat().toRawBits() } }
        val actual = uniformFrames(frames, replayIndex = 8)

        assertEquals(expectedBits.zip(listOf(5, 0, 1, 1, 1, 1, 0, 1, 0, 4)), actual)
    }

    private fun uniformFrames(frames: List<DoubleArray>, replayIndex: Int): List<Pair<List<Int>, Int>> {
        val locations = mapOf("prefixUniform" to 1, "suffixUniform" to 5, "opacityUniform" to 9, "directionUniform" to 11)
        for ((fieldName, location) in locations) {
            ParticleRenderer::class.java.getDeclaredField(fieldName).apply {
                isAccessible = true
                setInt(renderer, location)
            }
        }
        val state = IntArray(14)
        var calls = 0
        var sourceImages = 0
        val record = Answer<Any?> { call ->
            when (call.method.name) {
                "glGenTextures" -> call.getArgument<IntArray>(1)[0] = ++sourceImages
                "glUseProgram" -> calls++
                "glUniform2f", "glUniform3f", "glUniform4f" -> {
                    val location = call.getArgument<Int>(0)
                    for (index in 1 until call.arguments.size) {
                        state[location + index - 1] = call.getArgument<Float>(index).toRawBits()
                    }
                    calls++
                }
            }
            null
        }
        return mockStatic(GLES20::class.java, record).use {
            renderer.uploadImage(ByteArray(16))
            frames.mapIndexed { index, frame ->
                if (index == replayIndex) {
                    renderer.releaseImage()
                    renderer.uploadImage(ByteArray(16))
                }
                calls = 0
                renderer.setFrame(frame)
                state.drop(1) to calls
            }
        }
    }

    private fun probeClears(handle: Long, renderer: ParticleRenderer = this.renderer): List<ProbeClear> {
        val clears = mutableListOf<ProbeClear>()
        var columns = IntRange.EMPTY
        var rows = IntRange.EMPTY
        var rgba = emptyList<Float>()
        val record = Answer<Any?> { call ->
            when (call.method.name) {
                "glScissor" -> {
                    val (x, y, width, height) = call.arguments.map { it as Int }
                    columns = x until x + width
                    rows = y until y + height
                }
                "glClearColor" -> rgba = call.arguments.map { it as Float }
                "glClear" -> clears += ProbeClear(columns, rows, rgba)
            }
            null
        }
        mockStatic(GLES20::class.java, record).use { renderer.drawReadinessProbe(handle) }
        return clears
    }

    private data class ProbeClear(val columns: IntRange, val rows: IntRange, val rgba: List<Float>)
}
