package dev.ventairy.oh_my_flutter.motion

import android.opengl.GLES20
import android.opengl.GLES30
import kotlin.test.Test
import kotlin.test.assertEquals
import org.mockito.Answers.RETURNS_DEFAULTS
import org.mockito.Mockito.mock
import org.mockito.Mockito.mockStatic
import org.mockito.invocation.InvocationOnMock
import org.mockito.stubbing.Answer

class ParticleGaussianTest {
    @Test
    fun `when the fragment shader fails, it should release both shader handles`() {
        val gl = ResourceRecorder(rejectFragmentShader = true)
        val failure = gl.record { runCatching { ParticleGaussian(66, 31, false, false, false) }.exceptionOrNull() }

        assertEquals(Triple(true, listOf("shader", "shader"), true), gl.cleanup(failure))
    }

    @Test
    fun `when the second framebuffer is incomplete, it should release all allocated resources`() {
        val gl = ResourceRecorder(rejectSecondFramebuffer = true)
        val failure = gl.record { runCatching { createRenderer().uploadImage(ByteArray(16)) }.exceptionOrNull() }

        assertEquals(Triple(true, gaussianResources, true), gl.cleanup(failure))
    }

    @Test
    fun `when the Gaussian buffer is released, it should return every resource exactly once`() {
        val gl = ResourceRecorder()
        gl.record {
            val gaussian = ParticleGaussian(66, 31, false, false, false)
            gaussian.prepareTargets()
            gaussian.release()
            gaussian.release()
        }

        assertEquals(Triple(false, gaussianResources, true), gl.cleanup())
    }

    @Test
    fun `when the particle image retires, it should discard targets and reuse the program on replay`() {
        val gl = ResourceRecorder()
        val renderer = createRenderer()
        val firstImageReleases = gl.record {
            renderer.uploadImage(ByteArray(16))
            renderer.releaseImage()
            val released = gl.releasedKinds()
            renderer.uploadImage(ByteArray(16))
            renderer.release()
            released
        }

        val expectedFirst = listOf("framebuffer", "framebuffer", "shader", "shader", "texture", "texture", "texture")
        val expectedTotal = (gaussianResources + List(2) { "framebuffer" } + List(4) { "texture" }).sorted()
        assertEquals(expectedFirst to Triple(false, expectedTotal, true), firstImageReleases to gl.cleanup())
    }

    @Test
    fun `when a Gaussian pulse ends, it should restore the particle state without uploading unchanged uniforms`() {
        val gl = ResourceRecorder()
        val renderer = createRenderer()
        ParticleRenderer::class.java.getDeclaredField("program").apply {
            isAccessible = true
            setInt(renderer, particleProgram)
        }
        ParticleRenderer::class.java.getDeclaredField("geometry").apply {
            isAccessible = true
            set(renderer, mock(ParticleGeometry::class.java))
        }
        val sharp = doubleArrayOf(0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, -.5, .5, 1.0, 0.0, 0.0)
        val peak = sharp.copyOf().apply {
            this[0] = .45
            this[14] = 8.0
            this[15] = 10.0
        }
        val recovery = sharp.copyOf().apply { this[0] = .85 }

        gl.record {
            renderer.uploadImage(ByteArray(16))
            GLES20.glViewport(0, 0, 66, 31)
            GLES20.glEnable(GLES20.GL_BLEND)
            for (frame in listOf(sharp, peak, recovery)) {
                renderer.setFrame(frame)
                renderer.draw(frame[0].toFloat())
            }
            renderer.release()
        }

        val expectedStates = listOf(true, false, true).map { onSurface ->
            DrawState(onSurface, true, particleProgram, true, 66 to 31)
        }
        assertEquals(Triple(expectedStates, 2, 4), Triple(gl.particleDraws, gl.gaussianDraws, gl.packedUniforms))
    }

    @Test
    fun `when legacy Skia blur stays below the rescale threshold, it should filter at capture density`() {
        val gl = ResourceRecorder()
        gl.record {
            val gaussian = ParticleGaussian(672, 392, true, true, false)
            gaussian.prepareTargets()
            gaussian.drawResult(3.6f, 3.6f)
            gaussian.release()
        }

        assertEquals(
            listOf(6, 6) to listOf(672 to 392, 672 to 392),
            gl.kernelPairs to gl.gaussianViewports,
        )
    }

    @Test
    fun `when managed Skia blur exceeds the per-pass sigma, it should keep its full-size vertical draw`() {
        val gl = ResourceRecorder()
        gl.record {
            val gaussian = ParticleGaussian(672, 392, true, false, false)
            gaussian.prepareTargets()
            gaussian.drawResult(8f, 8f)
            gaussian.release()
        }

        assertEquals(listOf(12, 12) to listOf(336 to 196, 672 to 392), gl.kernelPairs to gl.gaussianViewports)
    }

    @Test
    fun `when full-density Skia downsamples an odd viewport, it should sample only the drawn region`() {
        val gl = ResourceRecorder()
        gl.record {
            val gaussian = ParticleGaussian(1009, 589, true, false, true)
            gaussian.prepareTargets()
            gaussian.drawResult(12f, 12f)
            gaussian.release()
        }

        val full = 1009 to 589
        val reduced = 336 to 196
        val output = GaussianOutput(
            passes = listOf(
                GaussianPass(504 to 294, input = 0, output = 1, pairs = 0),
                GaussianPass(reduced, input = 1, output = 0, pairs = 12),
                GaussianPass(reduced, input = 0, output = 1, pairs = 6),
                GaussianPass(full, input = 0, output = null, pairs = 12, scissor = listOf(0, 0, 1009, 38)),
                GaussianPass(full, input = 0, output = null, pairs = 12, scissor = listOf(0, 551, 1009, 38)),
                GaussianPass(full, input = 1, output = null, pairs = 0, scissor = listOf(0, 38, 1009, 513)),
            ),
            surfaceClears = listOf(null),
            programUses = 1,
            scissorEnabled = false,
        )
        val sampledRegions = listOf(1f to 1f, 504f / 1009 to 294f / 589, 336f / 1009 to 196f / 589)
        assertEquals(output to sampledRegions, gl.gaussianOutput() to gl.sampledRegions)
    }

    @Test
    fun `when legacy Skia downsamples an even viewport, it should filter both borders at full size`() {
        assertLegacyGaussianPasses(width = 672, height = 392, borderRows = 25)
    }

    @Test
    fun `when legacy Skia downsamples an odd viewport, it should keep the exact interior row`() {
        assertLegacyGaussianPasses(width = 673, height = 49, borderRows = 24)
    }

    @Test
    fun `when legacy Skia has no interior rows to upscale, it should keep the full-size vertical draw`() {
        val gl = ResourceRecorder()
        gl.record {
            val gaussian = ParticleGaussian(66, 31, true, true, false)
            gaussian.prepareTargets()
            gaussian.drawResult(8f, 8f)
            gaussian.release()
        }

        assertEquals(listOf(12, 12) to listOf(33 to 16, 66 to 31), gl.kernelPairs to gl.gaussianViewports)
    }

    @Test
    fun `when an edge draw fails, it should disable scissoring before returning to the particle renderer`() {
        val gl = ResourceRecorder(rejectScissoredDraw = true)
        val failure = gl.record {
            val gaussian = ParticleGaussian(672, 392, true, true, false)
            gaussian.prepareTargets()
            val error = runCatching { gaussian.drawResult(8f, 8f) }.exceptionOrNull()
            gaussian.release()
            error
        }

        assertEquals(true to false, (failure is IllegalStateException) to gl.scissorEnabled)
    }

    private fun assertLegacyGaussianPasses(width: Int, height: Int, borderRows: Int) {
        val gl = ResourceRecorder()
        gl.record {
            val gaussian = ParticleGaussian(width, height, true, true, false)
            gaussian.prepareTargets()
            gaussian.drawResult(8f, 8f)
            gaussian.release()
        }

        val reduced = (width + 1) / 2 to (height + 1) / 2
        val full = width to height
        val expected = GaussianOutput(
            passes = listOf(
                GaussianPass(reduced, input = 0, output = 1, pairs = 12),
                GaussianPass(reduced, input = 1, output = 0, pairs = 12),
                GaussianPass(full, input = 1, output = null, pairs = 12, scissor = listOf(0, 0, width, borderRows)),
                GaussianPass(
                    full,
                    input = 1,
                    output = null,
                    pairs = 12,
                    scissor = listOf(0, height - borderRows, width, borderRows),
                ),
                GaussianPass(
                    full,
                    input = 0,
                    output = null,
                    pairs = 0,
                    scissor = listOf(0, borderRows, width, height - 2 * borderRows),
                ),
            ),
            surfaceClears = listOf(null),
            programUses = 1,
            scissorEnabled = false,
        )
        assertEquals(expected, gl.gaussianOutput())
    }

    private fun createRenderer() = ParticleRenderer(
        DisintegrateConfiguration(
            mapOf(
                "width" to 2, "height" to 2, "viewportWidth" to 66, "viewportHeight" to 31,
                "originX" to 0, "originY" to 0, "scaleX" to 1, "scaleY" to 1,
                "pointPadding" to 2, "maximumParticleCount" to 4, "minimumCellSize" to 1,
                "seed" to 42, "geometryParameters" to DoubleArray(10), "nativeGaussian" to true,
                "vertexSource" to "unused", "fragmentSource" to "unused",
            ),
        ),
    )

    private data class DrawState(
        val onSurface: Boolean,
        val sourceBound: Boolean,
        val program: Int,
        val blends: Boolean,
        val viewport: Pair<Int, Int>,
    )

    private data class GaussianPass(
        val viewport: Pair<Int, Int>,
        val input: Int,
        val output: Int?,
        val pairs: Int,
        val scissor: List<Int>? = null,
    )

    private data class GaussianOutput(
        val passes: List<GaussianPass>,
        val surfaceClears: List<List<Int>?>,
        val programUses: Int,
        val scissorEnabled: Boolean,
    )

    private class ResourceRecorder(
        private val rejectFragmentShader: Boolean = false,
        private val rejectSecondFramebuffer: Boolean = false,
        private val rejectScissoredDraw: Boolean = false,
    ) : Answer<Any?> {
        private val allocations = mutableMapOf<Int, String>()
        private val releases = mutableListOf<Int>()
        private var fragmentShader = 0
        private var framebufferChecks = 0
        private var currentFramebuffer = 0
        private var currentProgram = 0
        private var currentTexture = 0
        private var blendEnabled = false
        private var viewport = 0 to 0
        private var scissor = listOf(0, 0, 0, 0)
        private var programUses = 0
        private var activePairs = 0
        private val gaussianPasses = mutableListOf<GaussianPass>()
        private val surfaceClears = mutableListOf<List<Int>?>()
        val particleDraws = mutableListOf<DrawState>()
        val gaussianViewports get() = gaussianPasses.map(GaussianPass::viewport)
        val kernelPairs = mutableListOf<Int>()
        val sampledRegions = mutableListOf<Pair<Float, Float>>()
        val gaussianDraws get() = gaussianPasses.size
        var scissorEnabled = false
            private set
        var packedUniforms = 0
            private set

        fun <T> record(run: () -> T): T = mockStatic(GLES20::class.java, this).use {
            mockStatic(GLES30::class.java, this).use { run() }
        }

        fun cleanup(failure: Throwable? = null) =
            Triple(failure is IllegalStateException, allocations.values.sorted(), allocations.keys.sorted() == releases.sorted())

        fun releasedKinds(): List<String> = releases.map(allocations::getValue).sorted()

        fun gaussianOutput() = GaussianOutput(gaussianPasses, surfaceClears, programUses, scissorEnabled)

        override fun answer(call: InvocationOnMock): Any? {
            when (call.method.name) {
                "glCreateShader" -> {
                    val shader = allocate("shader")
                    if (call.getArgument<Int>(0) == GLES20.GL_FRAGMENT_SHADER) fragmentShader = shader
                    return shader
                }
                "glCreateProgram" -> return allocate("program")
                "glGetShaderiv" -> {
                    val compileFailed = rejectFragmentShader && call.getArgument<Int>(0) == fragmentShader
                    writeInteger(call, offsetIndex = 3, value = if (compileFailed) 0 else 1)
                }
                "glGetProgramiv" -> writeInteger(call, offsetIndex = 3, value = 1)
                "glGetUniformLocation" -> return when (call.getArgument<String>(1)) {
                    "uPairs" -> pairsUniform
                    "uContent" -> contentUniform
                    else -> 1
                }
                "glGenTextures" -> allocateNames(call, "texture")
                "glGenFramebuffers" -> allocateNames(call, "framebuffer")
                "glDeleteShader", "glDeleteProgram" -> releases += call.getArgument<Int>(0)
                "glDeleteTextures", "glDeleteFramebuffers" -> {
                    val offset = call.getArgument<Int>(2)
                    releases += call.getArgument<IntArray>(1).drop(offset).take(call.getArgument<Int>(0)).filter { it != 0 }
                }
                "glCheckFramebufferStatus" -> {
                    framebufferChecks++
                    return if (rejectSecondFramebuffer && framebufferChecks == 2) {
                        GLES20.GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT
                    } else {
                        GLES20.GL_FRAMEBUFFER_COMPLETE
                    }
                }
                "glBindFramebuffer" -> currentFramebuffer = call.getArgument(1)
                "glUseProgram" -> {
                    currentProgram = call.getArgument(0)
                    programUses++
                }
                "glBindTexture" -> currentTexture = call.getArgument(1)
                "glEnable", "glDisable" -> {
                    when (call.getArgument<Int>(0)) {
                        GLES20.GL_BLEND -> blendEnabled = call.method.name == "glEnable"
                        GLES20.GL_SCISSOR_TEST -> scissorEnabled = call.method.name == "glEnable"
                    }
                }
                "glViewport" -> viewport = call.getArgument<Int>(2) to call.getArgument(3)
                "glScissor" -> scissor = List(4) { call.getArgument<Int>(it) }
                "glClear" -> if (currentFramebuffer == 0) surfaceClears += scissor.takeIf { scissorEnabled }
                "glUniform1i" -> if (call.getArgument<Int>(0) == pairsUniform) activePairs = call.getArgument(1)
                "glUniform2f", "glUniform3f", "glUniform4f" -> {
                    if (currentProgram == particleProgram) packedUniforms++
                    if (call.method.name == "glUniform2f" && call.getArgument<Int>(0) == contentUniform) {
                        sampledRegions += call.getArgument<Float>(1) to call.getArgument(2)
                    }
                }
                "glUniform2fv" -> kernelPairs += call.getArgument<Int>(1)
                "glDrawArrays" -> {
                    when (call.getArgument<Int>(0)) {
                        GLES20.GL_POINTS -> {
                            val sourceTexture = allocations.entries.last { it.value == "texture" }.key
                            particleDraws += DrawState(
                                currentFramebuffer == 0,
                                currentTexture == sourceTexture,
                                currentProgram,
                                blendEnabled,
                                viewport,
                            )
                        }
                        GLES20.GL_TRIANGLES -> {
                            if (scissorEnabled && rejectScissoredDraw) error("Scissored draw rejected")
                            gaussianPasses += GaussianPass(
                                viewport = viewport,
                                input = slot("texture", currentTexture),
                                output = currentFramebuffer.takeUnless { it == 0 }?.let { slot("framebuffer", it) },
                                pairs = activePairs,
                                scissor = scissor.takeIf { scissorEnabled },
                            )
                        }
                    }
                }
            }
            return RETURNS_DEFAULTS.answer(call)
        }

        private fun slot(kind: String, id: Int) = allocations.filterValues { it == kind }.keys.indexOf(id)

        private fun allocate(kind: String): Int {
            val id = allocations.size + 1
            allocations[id] = kind
            return id
        }

        private fun allocateNames(call: InvocationOnMock, kind: String) {
            val offset = call.getArgument<Int>(2)
            val names = call.getArgument<IntArray>(1)
            repeat(call.getArgument<Int>(0)) { names[offset + it] = allocate(kind) }
        }

        private fun writeInteger(call: InvocationOnMock, offsetIndex: Int, value: Int) {
            call.getArgument<IntArray>(offsetIndex - 1)[call.getArgument<Int>(offsetIndex)] = value
        }
    }

    private companion object {
        const val particleProgram = 99
        const val pairsUniform = 100
        const val contentUniform = 101
        val gaussianResources = listOf("framebuffer", "framebuffer", "program", "shader", "shader", "texture", "texture")
    }
}
