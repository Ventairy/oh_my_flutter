package dev.ventairy.oh_my_flutter.motion;

import android.opengl.GLES30;
import java.nio.ByteBuffer;
import java.util.HashMap;
import java.util.Map;

final class ParticleRenderer {
    static final int READINESS_PROBE_WIDTH = 22;
    private final DisintegrateConfiguration configuration;
    private final int[] uniformBits = new int[14];
    private boolean hasUniforms;
    private ParticleGeometry geometry;
    private int program;
    private int sourceTexture;
    private int vertexBuffer;
    private int vertexArray;
    private int progressUniform;
    private int prefixUniform;
    private int suffixUniform;
    private int opacityUniform;
    private int directionUniform;
    private ParticleGaussian gaussian;
    private float blurSigma;
    private float displaySigma;

    ParticleRenderer(DisintegrateConfiguration configuration) {
        this.configuration = configuration;
    }

    void initialize(RenderTimings timings) {
        RenderTimings.phase(timings, "geometryGenerate", () -> geometry = new ParticleGeometry(configuration));
        RenderTimings.phase(timings, "programCompileLink", () -> {
            program = createProgram();
            progressUniform = GLES30.glGetUniformLocation(program, "uProgress");
            prefixUniform = GLES30.glGetUniformLocation(program, "uPrefix");
            suffixUniform = GLES30.glGetUniformLocation(program, "uSuffix");
            opacityUniform = GLES30.glGetUniformLocation(program, "uOpacity");
            directionUniform = GLES30.glGetUniformLocation(program, "uDirection");
        });
        RenderTimings.phase(timings, "geometryUpload", this::uploadGeometry);
        RenderTimings.phase(timings, "programBindingsAndChecks", this::configureProgram);
    }

    void uploadImage(byte[] pixels) {
        if (pixels.length != (long) configuration.width * configuration.height * 4) {
            throw new IllegalArgumentException("Expected premultiplied RGBA pixels matching the image dimensions.");
        }
        if (configuration.nativeGaussian) prepareGaussian();
        if (sourceTexture != 0) {
            GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, sourceTexture);
            GLES30.glTexSubImage2D(GLES30.GL_TEXTURE_2D, 0, 0, 0, configuration.width, configuration.height,
                GLES30.GL_RGBA, GLES30.GL_UNSIGNED_BYTE, ByteBuffer.wrap(pixels));
            return;
        }
        int[] handle = new int[1];
        GLES30.glGenTextures(1, handle, 0);
        sourceTexture = handle[0];
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, sourceTexture);
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_NEAREST);
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_NEAREST);
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE);
        GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE);
        GLES30.glTexImage2D(GLES30.GL_TEXTURE_2D, 0, GLES30.GL_RGBA, configuration.width, configuration.height, 0,
            GLES30.GL_RGBA, GLES30.GL_UNSIGNED_BYTE, ByteBuffer.wrap(pixels));
    }

    void draw(float progress) {
        if (gaussian == null || blurSigma == 0 || progress >= 1) {
            drawParticles(progress);
            return;
        }
        if (Float.intBitsToFloat(uniformBits[9]) == 0 || Float.intBitsToFloat(uniformBits[10]) == 0) {
            GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT);
            return;
        }
        try {
            gaussian.bindSource();
            drawParticles(progress);
            gaussian.drawResult(blurSigma, displaySigma);
        } catch (RuntimeException | LinkageError error) {
            GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0);
            GLES30.glViewport(0, 0, configuration.viewportWidth, configuration.viewportHeight);
            throw error;
        } finally {
            GLES30.glUseProgram(program);
            GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, sourceTexture);
            GLES30.glEnable(GLES30.GL_BLEND);
        }
    }

    private void drawParticles(float progress) {
        GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT);
        if (progress >= 1) return;
        GLES30.glUniform1f(progressUniform, progress);
        GLES30.glDrawArrays(GLES30.GL_POINTS, 0, geometry.particleCount);
    }

    void setFrame(double[] frame) {
        int expectedLength = configuration.nativeGaussian ? 16 : 14;
        if (frame == null || frame.length != expectedLength) {
            throw new IllegalArgumentException("Expected " + expectedLength + " frame parameters.");
        }
        for (double value : frame) if (!Double.isFinite(value)) throw new IllegalArgumentException("Expected finite frame parameters.");
        if (configuration.nativeGaussian) {
            float nextBlurSigma = (float) frame[14];
            float nextDisplaySigma = (float) frame[15];
            if (frame[14] < 0 || frame[15] < 0 || !Float.isFinite(nextBlurSigma) || !Float.isFinite(nextDisplaySigma)
                    || (nextBlurSigma == 0) != (nextDisplaySigma == 0)) {
                throw new IllegalArgumentException("Expected matching finite and nonnegative Gaussian sigmas.");
            }
            blurSigma = nextBlurSigma;
            displaySigma = nextDisplaySigma;
        }
        // The renderer owns its context, so the particle program stays bound.
        if (!hasUniforms) GLES30.glUseProgram(program);
        if (updateUniformGroup(frame, 1, 5)) {
            GLES30.glUniform4f(prefixUniform, (float) frame[1], (float) frame[2], (float) frame[3], (float) frame[4]);
        }
        if (updateUniformGroup(frame, 5, 9)) {
            GLES30.glUniform4f(suffixUniform, (float) frame[5], (float) frame[6], (float) frame[7], (float) frame[8]);
        }
        if (updateUniformGroup(frame, 9, 11)) {
            GLES30.glUniform2f(opacityUniform, (float) frame[9], (float) frame[10]);
        }
        if (updateUniformGroup(frame, 11, 14)) {
            GLES30.glUniform3f(directionUniform, (float) frame[11], (float) frame[12], (float) frame[13]);
        }
        hasUniforms = true;
    }

    private boolean updateUniformGroup(double[] frame, int start, int end) {
        boolean changed = !hasUniforms;
        for (int index = start; index < end; index++) {
            int bits = Float.floatToRawIntBits((float) frame[index]);
            changed |= uniformBits[index] != bits;
            uniformBits[index] = bits;
        }
        return changed;
    }

    void drawReadinessProbe(long imageHandle) {
        // A private, clipped row identifies this exact image across Flutter's texture import.
        GLES30.glEnable(GLES30.GL_SCISSOR_TEST);
        long remainingBits = imageHandle;
        int runStart = 0;
        int color = (int) remainingBits & 7;
        for (int nextPixel = 1; nextPixel <= READINESS_PROBE_WIDTH; nextPixel++) {
            remainingBits >>>= 3;
            int nextColor = (int) remainingBits & 7;
            if (nextPixel < READINESS_PROBE_WIDTH && nextColor == color) continue;

            GLES30.glScissor(runStart, configuration.viewportHeight, nextPixel - runStart, 1);
            GLES30.glClearColor(color & 1, (color >>> 1) & 1, (color >>> 2) & 1, 1);
            GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT);
            runStart = nextPixel;
            color = nextColor;
        }
        GLES30.glDisable(GLES30.GL_SCISSOR_TEST);
        GLES30.glClearColor(0, 0, 0, 0);
    }

    Map<String, Object> capabilities() {
        Map<String, Object> values = new HashMap<>();
        values.put("glVendor", GLES30.glGetString(GLES30.GL_VENDOR));
        values.put("glRenderer", GLES30.glGetString(GLES30.GL_RENDERER));
        values.put("glVersion", GLES30.glGetString(GLES30.GL_VERSION));
        values.put("particleCount", geometry.particleCount);
        values.put("geometryBytes", geometry.particleCount * ParticleGeometry.ATTRIBUTE_STRIDE_BYTES);
        values.put("columns", geometry.columns);
        values.put("rows", geometry.rows);
        return values;
    }

    void releaseImage() {
        if (gaussian != null) gaussian.releaseTargets();
        if (sourceTexture == 0) return;
        GLES30.glDeleteTextures(1, new int[] {sourceTexture}, 0);
        sourceTexture = 0;
    }

    void release() {
        releaseImage();
        if (gaussian != null) {
            gaussian.release();
            gaussian = null;
        }
        if (vertexBuffer != 0) GLES30.glDeleteBuffers(1, new int[] {vertexBuffer}, 0);
        if (vertexArray != 0) GLES30.glDeleteVertexArrays(1, new int[] {vertexArray}, 0);
        if (program != 0) GLES30.glDeleteProgram(program);
        vertexBuffer = 0;
        vertexArray = 0;
        program = 0;
        hasUniforms = false;
    }

    private void prepareGaussian() {
        if (gaussian == null) {
            gaussian = new ParticleGaussian(configuration.viewportWidth, configuration.viewportHeight,
                configuration.skiaGaussian, configuration.legacyGaussian, configuration.fullDensityGaussian);
        }
        try {
            gaussian.prepareTargets();
        } catch (RuntimeException | LinkageError error) {
            gaussian.release();
            gaussian = null;
            throw error;
        }
    }

    private void uploadGeometry() {
        int[] handle = new int[1];
        GLES30.glGenVertexArrays(1, handle, 0);
        vertexArray = handle[0];
        GLES30.glBindVertexArray(vertexArray);
        GLES30.glGenBuffers(1, handle, 0);
        vertexBuffer = handle[0];
        GLES30.glBindBuffer(GLES30.GL_ARRAY_BUFFER, vertexBuffer);
        ByteBuffer attributes = geometry.createUploadView();
        GLES30.glBufferData(GLES30.GL_ARRAY_BUFFER, attributes.capacity(), attributes, GLES30.GL_STATIC_DRAW);
        GLES30.glEnableVertexAttribArray(0);
        GLES30.glVertexAttribPointer(0, 4, GLES30.GL_FLOAT, false, ParticleGeometry.ATTRIBUTE_STRIDE_BYTES, 0);
        GLES30.glEnableVertexAttribArray(1);
        GLES30.glVertexAttribPointer(1, 4, GLES30.GL_FLOAT, false, ParticleGeometry.ATTRIBUTE_STRIDE_BYTES, 16);
        GLES30.glEnableVertexAttribArray(2);
        GLES30.glVertexAttribPointer(2, 2, GLES30.GL_FLOAT, false, ParticleGeometry.ATTRIBUTE_STRIDE_BYTES, 32);
    }

    private void configureProgram() {
        // This renderer exclusively owns its EGL context, so fixed GL state stays bound between frames.
        GLES30.glViewport(0, 0, configuration.viewportWidth, configuration.viewportHeight);
        GLES30.glClearColor(0, 0, 0, 0);
        GLES30.glUseProgram(program);
        GLES30.glActiveTexture(GLES30.GL_TEXTURE0);
        GLES30.glBindVertexArray(vertexArray);
        GLES30.glUniform1i(GLES30.glGetUniformLocation(program, "uImage"), 0);
        GLES30.glUniform2f(GLES30.glGetUniformLocation(program, "uImageSize"), configuration.width, configuration.height);
        GLES30.glUniform2f(GLES30.glGetUniformLocation(program, "uViewport"), configuration.viewportWidth, configuration.viewportHeight);
        GLES30.glUniform2f(GLES30.glGetUniformLocation(program, "uOrigin"), configuration.originX, configuration.originY);
        GLES30.glUniform2f(GLES30.glGetUniformLocation(program, "uScale"), configuration.scaleX, configuration.scaleY);
        GLES30.glEnable(GLES30.GL_BLEND);
        GLES30.glBlendFunc(GLES30.GL_ONE, GLES30.GL_ONE_MINUS_SRC_ALPHA);
        int error = GLES30.glGetError();
        if (error != GLES30.GL_NO_ERROR) throw new IllegalStateException("GL initialization failed: 0x" + Integer.toHexString(error));
        float[] range = new float[2];
        GLES30.glGetFloatv(GLES30.GL_ALIASED_POINT_SIZE_RANGE, range, 0);
        double pointSize = Math.ceil(Math.max(geometry.maximumCellWidth * configuration.scaleX,
            geometry.maximumCellHeight * configuration.scaleY)) + configuration.pointPadding;
        if (pointSize > range[1]) throw new IllegalArgumentException("Particles exceed this GPU's point-size limit.");
    }

    private int createProgram() {
        return linkProgram(configuration.vertexSource, configuration.fragmentSource);
    }

    static int linkProgram(String vertexSource, String fragmentSource) {
        int vertex = compileShader(GLES30.GL_VERTEX_SHADER, vertexSource);
        int fragment = 0;
        int linked = 0;
        boolean success = false;
        try {
            fragment = compileShader(GLES30.GL_FRAGMENT_SHADER, fragmentSource);
            linked = GLES30.glCreateProgram();
            GLES30.glAttachShader(linked, vertex);
            GLES30.glAttachShader(linked, fragment);
            GLES30.glLinkProgram(linked);
            int[] status = new int[1];
            GLES30.glGetProgramiv(linked, GLES30.GL_LINK_STATUS, status, 0);
            if (status[0] == 0) throw new IllegalStateException(GLES30.glGetProgramInfoLog(linked));
            success = true;
            return linked;
        } finally {
            if (!success && linked != 0) GLES30.glDeleteProgram(linked);
            if (fragment != 0) GLES30.glDeleteShader(fragment);
            GLES30.glDeleteShader(vertex);
        }
    }

    private static int compileShader(int kind, String source) {
        int shader = GLES30.glCreateShader(kind);
        GLES30.glShaderSource(shader, source);
        GLES30.glCompileShader(shader);
        int[] status = new int[1];
        GLES30.glGetShaderiv(shader, GLES30.GL_COMPILE_STATUS, status, 0);
        if (status[0] == 0) {
            String message = GLES30.glGetShaderInfoLog(shader);
            GLES30.glDeleteShader(shader);
            throw new IllegalStateException(message);
        }
        return shader;
    }
}
