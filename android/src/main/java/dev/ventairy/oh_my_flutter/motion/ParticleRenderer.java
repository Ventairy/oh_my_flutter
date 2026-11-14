package dev.ventairy.oh_my_flutter.motion;

import android.opengl.GLES30;
import java.nio.ByteBuffer;
import java.util.HashMap;
import java.util.Map;

final class ParticleRenderer {
    static final int READINESS_PROBE_WIDTH = 22;
    private final DisintegrateConfiguration configuration;
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
        GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT);
        if (progress >= 1) return;
        GLES30.glUniform1f(progressUniform, progress);
        GLES30.glDrawArrays(GLES30.GL_POINTS, 0, geometry.particleCount);
    }

    void setFrame(double[] frame) {
        if (frame == null || frame.length != 14) throw new IllegalArgumentException("Expected fourteen frame parameters.");
        for (double value : frame) if (!Double.isFinite(value)) throw new IllegalArgumentException("Expected finite frame parameters.");
        GLES30.glUseProgram(program);
        GLES30.glUniform4f(prefixUniform, (float) frame[1], (float) frame[2], (float) frame[3], (float) frame[4]);
        GLES30.glUniform4f(suffixUniform, (float) frame[5], (float) frame[6], (float) frame[7], (float) frame[8]);
        GLES30.glUniform2f(opacityUniform, (float) frame[9], (float) frame[10]);
        GLES30.glUniform3f(directionUniform, (float) frame[11], (float) frame[12], (float) frame[13]);
    }

    void drawReadinessProbe(long imageHandle) {
        // A private, clipped row identifies this exact image across Flutter's texture import.
        GLES30.glEnable(GLES30.GL_SCISSOR_TEST);
        for (int pixel = 0; pixel < READINESS_PROBE_WIDTH; pixel++) {
            int bit = pixel * 3;
            float red = ((imageHandle >>> bit) & 1) != 0 ? 1 : 0;
            float green = bit + 1 < 64 && ((imageHandle >>> (bit + 1)) & 1) != 0 ? 1 : 0;
            float blue = bit + 2 < 64 && ((imageHandle >>> (bit + 2)) & 1) != 0 ? 1 : 0;
            GLES30.glScissor(pixel, configuration.viewportHeight, 1, 1);
            GLES30.glClearColor(red, green, blue, 1);
            GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT);
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
        if (sourceTexture == 0) return;
        GLES30.glDeleteTextures(1, new int[] {sourceTexture}, 0);
        sourceTexture = 0;
    }

    void release() {
        releaseImage();
        if (vertexBuffer != 0) GLES30.glDeleteBuffers(1, new int[] {vertexBuffer}, 0);
        if (vertexArray != 0) GLES30.glDeleteVertexArrays(1, new int[] {vertexArray}, 0);
        if (program != 0) GLES30.glDeleteProgram(program);
        vertexBuffer = 0;
        vertexArray = 0;
        program = 0;
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
        int vertex = compileShader(GLES30.GL_VERTEX_SHADER, configuration.vertexSource);
        int fragment = compileShader(GLES30.GL_FRAGMENT_SHADER, configuration.fragmentSource);
        int linked = GLES30.glCreateProgram();
        GLES30.glAttachShader(linked, vertex);
        GLES30.glAttachShader(linked, fragment);
        GLES30.glLinkProgram(linked);
        int[] status = new int[1];
        GLES30.glGetProgramiv(linked, GLES30.GL_LINK_STATUS, status, 0);
        GLES30.glDeleteShader(vertex);
        GLES30.glDeleteShader(fragment);
        if (status[0] == 0) {
            String message = GLES30.glGetProgramInfoLog(linked);
            GLES30.glDeleteProgram(linked);
            throw new IllegalStateException(message);
        }
        return linked;
    }

    private int compileShader(int kind, String source) {
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
