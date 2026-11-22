package dev.ventairy.oh_my_flutter.motion;

import android.opengl.GLES30;
import java.util.Arrays;

final class ParticleGaussian {
    private static final int MAX_PAIRS = 16;
    private static final float SKIA_MAX_PASS_SIGMA = 4f;
    private static final float SKIA_IDENTITY_SIGMA = .03f;
    private static final float SKIA_IDENTITY_RESCALE = .999f;
    private static final float SKIA_COLLAPSE_RESCALE = .9f;
    private static final String VERTEX = """
        #version 300 es
        precision highp float;
        out vec2 vUv;
        void main() {
            vec2 position = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));
            vUv = position;
            gl_Position = vec4(position * 2.0 - 1.0, 0.0, 1.0);
        }
        """;
    private static final String FRAGMENT = """
        #version 300 es
        precision highp float;
        uniform sampler2D uImage;
        uniform vec2 uStep;
        uniform vec2 uContent;
        uniform vec2 uHalfTexel;
        uniform float uCenter;
        uniform vec2 uKernel[16];
        uniform int uPairs;
        in vec2 vUv;
        out vec4 fragColor;
        vec4 sampleAt(vec2 point) {
            if (any(lessThan(point, vec2(0.0))) || any(greaterThan(point, vec2(1.0)))) {
                return vec4(0.0);
            }
            return texture(uImage, clamp(point * uContent, uHalfTexel, uContent - uHalfTexel));
        }
        void main() {
            vec4 color = sampleAt(vUv) * uCenter;
            for (int i = 0; i < uPairs; i++) {
                vec2 tap = uKernel[i];
                vec2 offset = uStep * tap.x;
                color += (sampleAt(vUv + offset) + sampleAt(vUv - offset)) * tap.y;
            }
            fragColor = color;
        }
        """;

    private final boolean skiaGaussian;
    private final boolean legacyGaussian;
    private final boolean fullDensityGaussian;
    private final int width;
    private final int height;
    private final int[] textures = new int[2];
    private final int[] framebuffers = new int[2];
    private final float[] kernel = new float[MAX_PAIRS * 2];
    private int program;
    private final int step;
    private final int content;
    private final int halfTexel;
    private final int center;
    private final int coefficients;
    private final int pairs;

    ParticleGaussian(int width, int height, boolean skiaGaussian, boolean legacyGaussian, boolean fullDensityGaussian) {
        this.skiaGaussian = skiaGaussian;
        this.legacyGaussian = legacyGaussian;
        this.fullDensityGaussian = fullDensityGaussian;
        this.width = width;
        this.height = height;
        program = ParticleRenderer.linkProgram(VERTEX, FRAGMENT);
        try {
            step = GLES30.glGetUniformLocation(program, "uStep");
            content = GLES30.glGetUniformLocation(program, "uContent");
            halfTexel = GLES30.glGetUniformLocation(program, "uHalfTexel");
            center = GLES30.glGetUniformLocation(program, "uCenter");
            coefficients = GLES30.glGetUniformLocation(program, "uKernel[0]");
            pairs = GLES30.glGetUniformLocation(program, "uPairs");
        } catch (RuntimeException | LinkageError error) {
            release();
            throw error;
        }
    }

    void prepareTargets() {
        if (framebuffers[0] != 0) return;
        try {
            allocateTargets();
        } catch (RuntimeException | LinkageError error) {
            releaseTargets();
            throw error;
        } finally {
            GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0);
        }
    }

    private void allocateTargets() {
        GLES30.glGenTextures(textures.length, textures, 0);
        GLES30.glGenFramebuffers(framebuffers.length, framebuffers, 0);
        for (int index = 0; index < framebuffers.length; index++) {
            if (textures[index] == 0 || framebuffers[index] == 0) {
                throw new IllegalStateException("Could not allocate a Gaussian target.");
            }
            GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textures[index]);
            GLES30.glTexStorage2D(GLES30.GL_TEXTURE_2D, 1, GLES30.GL_RGBA8, width, height);
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MIN_FILTER, GLES30.GL_LINEAR);
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_MAG_FILTER, GLES30.GL_LINEAR);
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_S, GLES30.GL_CLAMP_TO_EDGE);
            GLES30.glTexParameteri(GLES30.GL_TEXTURE_2D, GLES30.GL_TEXTURE_WRAP_T, GLES30.GL_CLAMP_TO_EDGE);
            GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, framebuffers[index]);
            GLES30.glFramebufferTexture2D(GLES30.GL_FRAMEBUFFER, GLES30.GL_COLOR_ATTACHMENT0,
                GLES30.GL_TEXTURE_2D, textures[index], 0);
            if (GLES30.glCheckFramebufferStatus(GLES30.GL_FRAMEBUFFER) != GLES30.GL_FRAMEBUFFER_COMPLETE) {
                throw new IllegalStateException("Incomplete Gaussian framebuffer.");
            }
        }
        requireNoError("Gaussian target setup");
    }

    void bindSource() {
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, framebuffers[0]);
    }

    void drawResult(float sigma, float displaySigma) {
        GLES30.glUseProgram(program);
        GLES30.glDisable(GLES30.GL_BLEND);
        GLES30.glUniform2f(halfTexel, .5f / width, .5f / height);
        if (fullDensityGaussian) drawFullDensityResult(sigma);
        else drawStandardResult(sigma, displaySigma);
        requireNoError("Gaussian draw");
    }

    private void drawStandardResult(float sigma, float displaySigma) {
        final int sizeDivisor = skiaGaussian ? skiaSizeDivisor(sigma) : sigma >= 4 ? 2 : 1;
        // The smaller target already interpolates when sampling between source texels.
        final boolean unpaired = sizeDivisor > 1;
        final int midWidth = (width + sizeDivisor - 1) / sizeDivisor;
        final int midHeight = (height + sizeDivisor - 1) / sizeDivisor;
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, framebuffers[1]);
        GLES30.glViewport(0, 0, midWidth, midHeight);
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textures[0]);
        GLES30.glUniform2f(content, 1, 1);
        GLES30.glUniform2f(step, 1f / midWidth, 0);
        final float horizontalSigma = sigma * midWidth / width;
        setKernel(horizontalSigma, kernelRadius(horizontalSigma, displaySigma, unpaired), unpaired);
        GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, 3);

        final float verticalSigma = sigma * midHeight / height;
        final int verticalRadius = kernelRadius(verticalSigma, displaySigma, unpaired);
        final int borderRows = legacyGaussian && unpaired ? verticalBorderRows(verticalRadius, midHeight) : 0;
        final boolean upscale = borderRows > 0 && borderRows * 2 < height;
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, upscale ? framebuffers[0] : 0);
        GLES30.glViewport(0, 0, upscale ? midWidth : width, upscale ? midHeight : height);
        if (!upscale) GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT);
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textures[1]);
        GLES30.glUniform2f(content, (float) midWidth / width, (float) midHeight / height);
        GLES30.glUniform2f(step, 0, 1f / midHeight);
        setKernel(verticalSigma, verticalRadius, unpaired);
        GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, 3);
        if (upscale) drawUpscaledResult(borderRows, textures[0]);
    }

    private void drawFullDensityResult(float sigma) {
        final float resize = sigma <= SKIA_MAX_PASS_SIGMA / SKIA_IDENTITY_RESCALE ? 1f : SKIA_MAX_PASS_SIGMA / sigma;
        final int midWidth = Math.max(1, Math.round(width * resize));
        final int midHeight = Math.max(1, Math.round(height * resize));
        final boolean resampled = resize < 1;
        // One half-size pass preserves source samples the final bilinear resize would otherwise skip.
        final boolean halfPass = resize * 2f < SKIA_COLLAPSE_RESCALE;
        final int sourceWidth = halfPass ? Math.max(1, width / 2) : width;
        final int sourceHeight = halfPass ? Math.max(1, height / 2) : height;
        if (halfPass) drawHalfSizeSource(sourceWidth, sourceHeight);

        final int horizontalIndex = halfPass ? 0 : 1;
        final int verticalIndex = 1 - horizontalIndex;
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, framebuffers[horizontalIndex]);
        GLES30.glViewport(0, 0, midWidth, midHeight);
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textures[verticalIndex]);
        GLES30.glUniform2f(content, (float) sourceWidth / width, (float) sourceHeight / height);
        GLES30.glUniform2f(step, 1f / midWidth, 0);
        final float horizontalSigma = sigma * midWidth / width;
        setKernel(horizontalSigma, kernelRadius(horizontalSigma, sigma, resampled), resampled);
        GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, 3);

        final float verticalSigma = sigma * midHeight / height;
        final int radius = kernelRadius(verticalSigma, sigma, resampled);
        final int borderRows = resampled ? verticalBorderRows(radius, midHeight) : 0;
        final boolean upscale = borderRows > 0 && borderRows * 2 < height;
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, upscale ? framebuffers[verticalIndex] : 0);
        GLES30.glViewport(0, 0, upscale ? midWidth : width, upscale ? midHeight : height);
        if (!upscale) GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT);
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textures[horizontalIndex]);
        GLES30.glUniform2f(content, (float) midWidth / width, (float) midHeight / height);
        GLES30.glUniform2f(step, 0, 1f / midHeight);
        // At intermediate texel centers, bilinear sampling can combine adjacent taps.
        setKernel(verticalSigma, radius, resampled && !upscale);
        GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, 3);
        if (upscale) {
            setKernel(verticalSigma, radius, true);
            drawUpscaledResult(borderRows, textures[verticalIndex]);
        }
    }

    private void drawHalfSizeSource(int halfWidth, int halfHeight) {
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, framebuffers[1]);
        GLES30.glViewport(0, 0, halfWidth, halfHeight);
        GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, textures[0]);
        GLES30.glUniform2f(content, 1, 1);
        GLES30.glUniform2f(step, 0, 0);
        GLES30.glUniform1f(center, 1);
        GLES30.glUniform1i(pairs, 0);
        GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, 3);
    }

    private int verticalBorderRows(int radius, int intermediateHeight) {
        // An interior row center lies at least (radius + 0.5) / intermediateHeight from each edge.
        final int denominator = 2 * intermediateHeight;
        final int numerator = (2 * radius + 1) * height - intermediateHeight;
        return (numerator + denominator - 1) / denominator;
    }

    private void drawUpscaledResult(int borderRows, int verticalTexture) {
        GLES30.glBindFramebuffer(GLES30.GL_FRAMEBUFFER, 0);
        GLES30.glViewport(0, 0, width, height);
        GLES30.glClear(GLES30.GL_COLOR_BUFFER_BIT);
        GLES30.glEnable(GLES30.GL_SCISSOR_TEST);
        try {
            // Keep the horizontal result and vertical kernel bound for the edges.
            GLES30.glScissor(0, 0, width, borderRows);
            GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, 3);
            GLES30.glScissor(0, height - borderRows, width, borderRows);
            GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, 3);

            // Interpolation commutes with the integer taps where they stay inside the image.
            GLES30.glScissor(0, borderRows, width, height - 2 * borderRows);
            GLES30.glBindTexture(GLES30.GL_TEXTURE_2D, verticalTexture);
            GLES30.glUniform1f(center, 1);
            GLES30.glUniform1i(pairs, 0);
            GLES30.glDrawArrays(GLES30.GL_TRIANGLES, 0, 3);
        } finally {
            GLES30.glDisable(GLES30.GL_SCISSOR_TEST);
        }
    }

    private int skiaSizeDivisor(float sigma) {
        if (sigma <= SKIA_MAX_PASS_SIGMA / SKIA_IDENTITY_RESCALE) return 1;
        int divisor = 2;
        // Skia collapses a final rescale pass when its additional scale would be at least 0.9.
        final int maximumUsefulDivisor = Math.max(width, height);
        while (divisor < maximumUsefulDivisor && sigma > SKIA_MAX_PASS_SIGMA * divisor / SKIA_COLLAPSE_RESCALE) divisor *= 2;
        return divisor;
    }

    private int kernelRadius(float sigma, float displaySigma, boolean unpaired) {
        if (skiaGaussian) {
            return sigma <= SKIA_IDENTITY_SIGMA ? 0 : (int) Math.ceil(3 * Math.min(sigma, SKIA_MAX_PASS_SIGMA));
        }
        final int displayRadius = Math.round((displaySigma - .5f) * 1.7320508f);
        final int fittedRadius = Math.round(displayRadius * sigma / displaySigma);
        return Math.max(0, Math.min(unpaired ? MAX_PAIRS : MAX_PAIRS * 2, fittedRadius));
    }

    private void setKernel(float sigma, int radius, boolean unpaired) {
        if (skiaGaussian) sigma = Math.min(sigma, SKIA_MAX_PASS_SIGMA);
        double variance = 2.0 * sigma * sigma;
        float weightSum = 1;
        int count = 0;
        for (int tap = 1; tap <= radius; tap += unpaired ? 1 : 2) {
            float first = (float) Math.exp(-tap * tap / variance);
            float second = unpaired || tap == radius ? 0 : (float) Math.exp(-(tap + 1) * (tap + 1) / variance);
            float weight = first + second;
            if (weight == 0) continue;
            kernel[count * 2] = tap + second / weight;
            kernel[count * 2 + 1] = weight;
            weightSum += weight * 2;
            count++;
        }
        for (int i = 0; i < count; i++) kernel[i * 2 + 1] /= weightSum;
        GLES30.glUniform1f(center, 1 / weightSum);
        GLES30.glUniform1i(pairs, count);
        if (count > 0) GLES30.glUniform2fv(coefficients, count, kernel, 0);
    }

    void releaseTargets() {
        if (framebuffers[0] != 0 || framebuffers[1] != 0) {
            GLES30.glDeleteFramebuffers(framebuffers.length, framebuffers, 0);
            Arrays.fill(framebuffers, 0);
        }
        if (textures[0] != 0 || textures[1] != 0) {
            GLES30.glDeleteTextures(textures.length, textures, 0);
            Arrays.fill(textures, 0);
        }
    }

    void release() {
        releaseTargets();
        if (program != 0) {
            GLES30.glDeleteProgram(program);
            program = 0;
        }
    }

    private static void requireNoError(String operation) {
        int error = GLES30.glGetError();
        if (error != GLES30.GL_NO_ERROR) {
            throw new IllegalStateException(operation + " failed: 0x" + Integer.toHexString(error));
        }
    }
}
