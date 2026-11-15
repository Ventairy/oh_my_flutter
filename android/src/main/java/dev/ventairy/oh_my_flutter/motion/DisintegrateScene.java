package dev.ventairy.oh_my_flutter.motion;

import android.os.Handler;
import android.os.HandlerThread;
import android.os.Process;
import android.view.Choreographer;
import java.util.HashMap;
import java.util.Map;
import java.util.function.Consumer;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.view.TextureRegistry;

final class DisintegrateScene implements Choreographer.FrameCallback {
    final long textureId;
    private final DisintegrateConfiguration configuration;
    private final Handler mainHandler;
    private final DisintegrateOutput output;
    private final HandlerThread renderThread = new HandlerThread("particle-disintegrate", Process.THREAD_PRIORITY_DISPLAY);
    private final Handler renderHandler;
    private final EglWindow window = new EglWindow();
    private volatile boolean closed;
    private volatile boolean surfaceInvalidated;
    private Choreographer choreographer;
    private ParticleRenderer renderer;
    private long imageHandle;
    private boolean imageReady;
    private MethodChannel.Result playResult;
    private MethodChannel.Result firstFrameResult;
    private long firstFrameTimestampNs;
    private long consumedFrameTimestampNs;
    private RenderTimings playbackTimings;
    private double startProgress;
    private long durationNs;
    private long startNs;
    private boolean countFrames;
    private int frameCount;

    DisintegrateScene(DisintegrateConfiguration configuration, TextureRegistry registry, Handler mainHandler,
            Consumer<DisintegrateScene> onInvalidated) {
        this.configuration = configuration;
        this.mainHandler = mainHandler;
        output = new DisintegrateOutput(registry, configuration.viewportWidth, configuration.viewportHeight,
            mainHandler, this::onFrameConsumed, () -> {
                surfaceInvalidated = true;
                mainHandler.post(() -> onInvalidated.accept(DisintegrateScene.this));
            });
        textureId = output.textureId;
        renderThread.start();
        renderHandler = new Handler(renderThread.getLooper());
    }

    boolean matches(DisintegrateConfiguration other) {
        return !closed && !surfaceInvalidated && configuration.matches(other);
    }

    boolean containsImage(long textureId, long handle) {
        return !closed && this.textureId == textureId && imageHandle == handle;
    }

    void prepareImage(byte[] pixels, long handle, boolean collectTimings, double[] frame,
            Consumer<Map<String, Object>> onPrepared, Consumer<Throwable> onFailure) {
        imageHandle = handle;
        RenderTimings timings = collectTimings ? new RenderTimings() : null;
        renderHandler.post(() -> {
            if (closed || surfaceInvalidated) {
                mainHandler.post(() -> onFailure.accept(new IllegalStateException("The renderer was released.")));
                return;
            }
            if (timings != null) timings.startWorker();
            boolean sceneReused = renderer != null;
            try {
                cancelFirstFrame("replaced", "The disintegration was replaced.");
                if (!sceneReused) {
                    RenderTimings.phase(timings, "eglInitialize", () -> window.initialize(output.surface));
                    choreographer = Choreographer.getInstance();
                    renderer = new ParticleRenderer(configuration);
                    renderer.initialize(timings);
                }
                RenderTimings.phase(timings, "imageUpload", () -> renderer.uploadImage(pixels));
                renderer.setFrame(frame);
                cancelPlayback("replaced", "The disintegration was replaced.");
                RenderTimings.phase(timings, "firstDraw", () -> draw(0));
                if (output.needsReadinessProbe) renderer.drawReadinessProbe(handle);
                firstFrameTimestampNs = System.nanoTime();
                output.expectFirstFrame(firstFrameTimestampNs);
                RenderTimings.phase(timings, "firstPresent", () -> window.present(firstFrameTimestampNs));
                imageReady = true;
                Map<String, Object> response = new HashMap<>();
                response.put("textureId", textureId);
                response.put("handle", handle);
                if (output.needsReadinessProbe) {
                    response.put("probeWidth", ParticleRenderer.READINESS_PROBE_WIDTH);
                    response.put("textureWidth", output.width);
                    response.put("textureHeight", output.height);
                    response.put("contentTop", 1);
                }
                if (timings != null) {
                    Map<String, Object> diagnostics = timings.preparation(sceneReused);
                    Map<String, Object> capabilities = renderer.capabilities();
                    capabilities.put("renderThreadPriority", Process.getThreadPriority(Process.myTid()));
                    capabilities.put("handlesCropAndRotation", !output.needsReadinessProbe);
                    diagnostics.put("capabilities", capabilities);
                    response.put("diagnostics", diagnostics);
                }
                mainHandler.post(() -> onPrepared.accept(response));
            } catch (RuntimeException | LinkageError error) {
                mainHandler.post(() -> onFailure.accept(error));
            }
        });
    }

    void awaitFirstFrame(MethodChannel.Result result) {
        renderHandler.post(() -> {
            if (closed || surfaceInvalidated || !imageReady) {
                mainHandler.post(() -> result.error("disposed", "The disintegration image was disposed.", null));
                return;
            }
            if (consumedFrameTimestampNs >= firstFrameTimestampNs) {
                mainHandler.post(() -> result.success(null));
                return;
            }
            if (firstFrameResult != null) {
                mainHandler.post(() -> result.error("waiting", "The first frame is already awaited.", null));
                return;
            }
            firstFrameResult = result;
        });
    }

    void play(double fromProgress, long durationMillis, boolean collectTimings,
            boolean collectFrameCount, MethodChannel.Result result) {
        renderHandler.post(() -> {
            if (closed || surfaceInvalidated || !imageReady) {
                mainHandler.post(() -> result.error("disposed", "The disintegration image was disposed.", null));
                return;
            }
            if (playResult != null) {
                mainHandler.post(() -> result.error("playing", "The disintegration is already playing.", null));
                return;
            }
            startProgress = fromProgress;
            durationNs = durationMillis * 1000000L;
            startNs = 0;
            playbackTimings = collectTimings ? new RenderTimings() : null;
            countFrames = collectFrameCount;
            frameCount = 0;
            playResult = result;
            choreographer.postFrameCallback(this);
        });
    }

    void setFrame(double[] values, MethodChannel.Result result) {
        final double[] frame = values.clone();
        renderHandler.post(() -> {
            if (closed || surfaceInvalidated || !imageReady) {
                mainHandler.post(() -> result.error("disposed", "The disintegration was disposed.", null));
                return;
            }
            try {
                renderer.setFrame(frame);
                draw((float) frame[0]);
                window.present(System.nanoTime());
                mainHandler.post(() -> result.success(null));
            } catch (RuntimeException error) {
                mainHandler.post(() -> result.error("render_failed", error.getMessage(), null));
            }
        });
    }

    void pause(MethodChannel.Result result) {
        renderHandler.post(() -> {
            MethodChannel.Result playing = stopPlayback();
            if (playing != null) mainHandler.post(() -> playing.success(null));
            mainHandler.post(() -> result.success(null));
        });
    }

    void releaseImage(MethodChannel.Result result) {
        renderHandler.post(() -> {
            cancelPlayback("disposed", "The disintegration image was disposed.");
            cancelFirstFrame("disposed", "The disintegration image was disposed.");
            imageReady = false;
            try {
                try {
                    if (!closed && !surfaceInvalidated && renderer != null) {
                        draw(1);
                        window.present(System.nanoTime());
                    }
                } finally {
                    if (renderer != null) renderer.releaseImage();
                }
                mainHandler.post(() -> result.success(null));
            } catch (RuntimeException error) {
                mainHandler.post(() -> result.error("render_failed", error.getMessage(), null));
            }
        });
    }

    void close(Runnable onReleased) {
        if (closed) {
            if (onReleased != null) mainHandler.post(onReleased);
            return;
        }
        closed = true;
        // Releasing the queue first unblocks an EGL swap when Flutter stops consuming frames.
        output.release();
        renderHandler.post(() -> {
            cancelPlayback("disposed", "The renderer was released.");
            cancelFirstFrame("disposed", "The renderer was released.");
            if (renderer != null) renderer.release();
            renderer = null;
            imageReady = false;
            window.release();
            if (onReleased != null) mainHandler.post(onReleased);
            renderThread.quitSafely();
        });
    }

    @Override
    public void doFrame(long frameTimeNs) {
        if (closed || surfaceInvalidated || playResult == null) return;
        if (startNs == 0) startNs = frameTimeNs;
        long finishNs = startNs + durationNs;
        double elapsed = Math.min(1, (double) (frameTimeNs - startNs) / durationNs);
        float progress = (float) (startProgress + (1 - startProgress) * elapsed);
        try {
            if (playbackTimings != null && frameTimeNs < finishNs) {
                playbackTimings.frame(frameTimeNs, () -> draw(progress), () -> window.present(frameTimeNs));
            } else {
                draw(progress);
                window.present(frameTimeNs);
            }
            if (countFrames && frameTimeNs < finishNs) frameCount++;
            if (frameTimeNs < finishNs) {
                choreographer.postFrameCallback(this);
                return;
            }
            Map<String, Object> response = null;
            if (playbackTimings != null) {
                response = playbackTimings.playback(startNs, finishNs, frameTimeNs);
            } else if (countFrames) {
                response = new HashMap<>();
                response.put("startNs", startNs);
                response.put("finishNs", finishNs);
                response.put("completedNs", frameTimeNs);
                response.put("frameCount", frameCount);
            }
            MethodChannel.Result result = stopPlayback();
            Map<String, Object> completedResponse = response;
            mainHandler.post(() -> result.success(completedResponse));
        } catch (RuntimeException error) {
            MethodChannel.Result result = stopPlayback();
            mainHandler.post(() -> result.error("render_failed", error.getMessage(), null));
        }
    }

    private void draw(float progress) {
        if (closed || surfaceInvalidated || !output.surface.isValid()) {
            throw new IllegalStateException("The renderer surface was released.");
        }
        renderer.draw(progress);
    }

    private void onFrameConsumed(long timestampNs) {
        if (closed || surfaceInvalidated) return;
        renderHandler.post(() -> {
            if (closed || surfaceInvalidated || !imageReady) return;
            consumedFrameTimestampNs = Math.max(consumedFrameTimestampNs, timestampNs);
            if (firstFrameResult == null || consumedFrameTimestampNs < firstFrameTimestampNs) return;
            MethodChannel.Result result = firstFrameResult;
            firstFrameResult = null;
            mainHandler.post(() -> result.success(null));
        });
    }

    private void cancelFirstFrame(String code, String message) {
        if (firstFrameResult == null) return;
        MethodChannel.Result result = firstFrameResult;
        firstFrameResult = null;
        mainHandler.post(() -> result.error(code, message, null));
    }

    private void cancelPlayback(String code, String message) {
        MethodChannel.Result result = stopPlayback();
        if (result != null) mainHandler.post(() -> result.error(code, message, null));
    }

    private MethodChannel.Result stopPlayback() {
        if (choreographer != null) choreographer.removeFrameCallback(this);
        MethodChannel.Result result = playResult;
        playResult = null;
        playbackTimings = null;
        countFrames = false;
        return result;
    }
}
