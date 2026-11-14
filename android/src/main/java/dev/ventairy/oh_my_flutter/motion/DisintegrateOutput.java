package dev.ventairy.oh_my_flutter.motion;

import android.content.ComponentCallbacks2;
import android.os.Handler;
import android.view.Surface;
import java.util.function.LongConsumer;
import io.flutter.view.TextureRegistry;

final class DisintegrateOutput {
    final long textureId;
    final Surface surface;
    final boolean needsReadinessProbe;
    final int width;
    final int height;
    private final TextureRegistry.SurfaceTextureEntry textureEntry;
    private final TextureRegistry.SurfaceProducer surfaceProducer;
    private final Handler mainHandler;
    private final LongConsumer onFrameAcquired;
    private final Object firstFrameLock = new Object();
    private volatile long expectedTimestampNs = Long.MAX_VALUE;
    private volatile boolean released;

    DisintegrateOutput(TextureRegistry registry, int width, int height, Handler mainHandler,
            LongConsumer onFrameAcquired, Runnable onInvalidated) {
        this.mainHandler = mainHandler;
        this.onFrameAcquired = onFrameAcquired;
        TextureRegistry.SurfaceProducer candidate = registry.createSurfaceProducer(TextureRegistry.SurfaceLifecycle.resetInBackground);
        try {
            candidate.setSize(width, height + 1);
            candidate.getSurface();
            if (!candidate.handlesCropAndRotation()) {
                this.width = Math.max(width, ParticleRenderer.READINESS_PROBE_WIDTH);
                this.height = height + 1;
                candidate.setSize(this.width, this.height);
                surfaceProducer = candidate;
                textureEntry = null;
                needsReadinessProbe = true;
                textureId = candidate.id();
                surface = candidate.getSurface();
                candidate.setCallback(new TextureRegistry.SurfaceProducer.Callback() {
                    @Override
                    public void onSurfaceCleanup() {
                        if (!released) onInvalidated.run();
                    }
                });
                return;
            }
        } catch (RuntimeException error) {
            candidate.release();
            throw error;
        }
        candidate.release();
        surfaceProducer = null;
        needsReadinessProbe = false;
        this.width = width;
        this.height = height;
        textureEntry = registry.createSurfaceTexture();
        textureId = textureEntry.id();
        try {
            textureEntry.surfaceTexture().setDefaultBufferSize(width, height);
            surface = new Surface(textureEntry.surfaceTexture());
        } catch (RuntimeException error) {
            textureEntry.release();
            throw error;
        }
        textureEntry.setOnFrameConsumedListener(() -> {
            if (released || expectedTimestampNs == Long.MAX_VALUE) return;
            // updateTexImage has just run on the raster thread; read that exact image's timestamp here.
            onImageAcquired(textureEntry.surfaceTexture().getTimestamp());
        });
        textureEntry.setOnTrimMemoryListener(level -> {
            if (level < ComponentCallbacks2.TRIM_MEMORY_BACKGROUND) return;
            mainHandler.post(() -> {
                if (!released) onInvalidated.run();
            });
        });
    }

    void expectFirstFrame(long timestampNs) {
        synchronized (firstFrameLock) {
            expectedTimestampNs = timestampNs;
        }
    }

    void release() {
        synchronized (firstFrameLock) {
            if (released) return;
            released = true;
            expectedTimestampNs = Long.MAX_VALUE;
        }
        if (surfaceProducer != null) {
            surfaceProducer.setCallback(null);
            surfaceProducer.release();
            return;
        }
        textureEntry.setOnFrameConsumedListener(null);
        textureEntry.setOnTrimMemoryListener(null);
        surface.release();
        textureEntry.release();
    }

    private void onImageAcquired(long timestampNs) {
        synchronized (firstFrameLock) {
            if (released || timestampNs < expectedTimestampNs) return;
            expectedTimestampNs = Long.MAX_VALUE;
        }
        mainHandler.post(() -> {
            if (!released) onFrameAcquired.accept(timestampNs);
        });
    }
}
