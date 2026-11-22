package dev.ventairy.oh_my_flutter.motion;

import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.os.Process;
import io.flutter.view.FakeSurfaceProducer;
import io.flutter.view.TextureRegistry;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public final class DisintegrateModernOutputTest {
    public static void main(String[] arguments) {
        retainsManagedOutputUntilCleanup();
        keepsTheGaussianGuardOutsideTheContentOnReplay();
        checksWorkerPriority(SceneFixture.configuration(), Process.THREAD_PRIORITY_DISPLAY);
        checksWorkerPriority(SceneFixture.configuration(true), Process.THREAD_PRIORITY_DISPLAY);
        checksWorkerPriority(SceneFixture.configuration(true, true), Process.THREAD_PRIORITY_DEFAULT);
        System.out.println("Disintegrate modern output regressions passed (11 checks).");
    }

    private static void retainsManagedOutputUntilCleanup() {
        FakeSurfaceProducer producer = new FakeSurfaceProducer(false);
        TextureRegistry registry = new TextureRegistry() {
            public SurfaceTextureEntry createSurfaceTexture() { throw new AssertionError("Modern output must retain the managed producer."); }
            public SurfaceProducer createSurfaceProducer(SurfaceLifecycle lifecycle) { return producer; }
        };
        DisintegrateScene scene = new DisintegrateScene(SceneFixture.configuration(), registry,
            new Handler(Looper.getMainLooper()), invalidated -> invalidated.close(null));
        List<Map<String, Object>> results = new ArrayList<>();
        HandlerThread worker = HandlerThread.latest();
        try {
            scene.prepareImage(new byte[16], 42, false, new double[14], results::add,
                error -> { throw new AssertionError(error); });
            worker.getLooper().drain();
            Looper.getMainLooper().drain();
            Map<String, Object> result = results.get(0);
            require(result.get("probeWidth").equals(22) && result.get("textureWidth").equals(22)
                && result.get("textureHeight").equals(11) && result.get("contentTop").equals(1),
                "The managed output must reserve a private row outside the ten-pixel content height.");
            require(ParticleRenderer.lastProbedHandle == 42, "The prepared pixels must carry their own image handle.");
            int firstPresent = EglWindow.presentCount;
            scene.releaseImage(true, new RecordingResult());
            worker.getLooper().drain();
            Looper.getMainLooper().drain();
            require(EglWindow.presentCount == firstPresent, "Completed managed output must avoid an extra swap.");
            scene.prepareImage(new byte[16], 43, false, new double[14], results::add,
                error -> { throw new AssertionError(error); });
            worker.getLooper().drain();
            Looper.getMainLooper().drain();
            require(result.get("textureId").equals(results.get(1).get("textureId")) && ParticleRenderer.lastProbedHandle == 43,
                "Replay must identify the replacement pixels on the same texture.");
            scene.releaseImage(false, new RecordingResult());
            worker.getLooper().drain();
            Looper.getMainLooper().drain();
            require(EglWindow.presentCount == firstPresent + 2, "Disposal can still clear the output before completion.");
            producer.triggerCleanup();
            worker.getLooper().drain();
            Looper.getMainLooper().drain();
            require(producer.releaseCount == 1 && !scene.containsImage(scene.textureId, 43),
                "Surface cleanup must invalidate the image and release the managed producer.");
        } finally {
            scene.close(null);
            worker.getLooper().drain();
            Looper.getMainLooper().drain();
        }
    }

    private static void keepsTheGaussianGuardOutsideTheContentOnReplay() {
        FakeSurfaceProducer producer = new FakeSurfaceProducer(false);
        TextureRegistry registry = new TextureRegistry() {
            public SurfaceTextureEntry createSurfaceTexture() { throw new AssertionError("Expected managed output."); }
            public SurfaceProducer createSurfaceProducer(SurfaceLifecycle lifecycle) { return producer; }
        };
        DisintegrateScene scene = new DisintegrateScene(SceneFixture.configuration(true), registry,
            new Handler(Looper.getMainLooper()), invalidated -> invalidated.close(null));
        HandlerThread worker = HandlerThread.latest();
        List<Map<String, Object>> results = new ArrayList<>();
        try {
            double[] frame = new double[16];
            frame[0] = 0.375;
            scene.prepareImage(new byte[16], Long.MAX_VALUE, false, frame, results::add,
                error -> { throw new AssertionError(error); });
            worker.getLooper().drain();
            Looper.getMainLooper().drain();
            require(ParticleRenderer.lastDrawProgress == 0.375f,
                "The first Gaussian image must show the driven pose that Flutter requested.");
            RecordingResult disposal = new RecordingResult();
            scene.releaseImage(true, disposal);
            worker.getLooper().drain();
            Looper.getMainLooper().drain();
            scene.prepareImage(new byte[16], Long.MIN_VALUE, false, new double[16], results::add,
                error -> { throw new AssertionError(error); });
            worker.getLooper().drain();
            Looper.getMainLooper().drain();
            List<Map<String, Object>> expected = List.of(
                Map.of("textureId", producer.id(), "handle", Long.MAX_VALUE, "nativeGaussian", true,
                    "probeWidth", 22, "textureWidth", 22, "textureHeight", 11, "contentTop", 1),
                Map.of("textureId", producer.id(), "handle", Long.MIN_VALUE, "nativeGaussian", true,
                    "probeWidth", 22, "textureWidth", 22, "textureHeight", 11, "contentTop", 1)
            );
            require(results.equals(expected) && producer.width == 22 && producer.height == 11
                && ParticleRenderer.lastProbedHandle == Long.MIN_VALUE && disposal.successCount == 1,
                "Gaussian replay must retain the producer, reserve the marker row and publish a fresh signed handle.");
        } finally {
            scene.close(null);
            worker.getLooper().drain();
            Looper.getMainLooper().drain();
        }
    }

    private static void require(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }

    private static void checksWorkerPriority(DisintegrateConfiguration configuration, int expectedPriority) {
        FakeSurfaceProducer producer = new FakeSurfaceProducer(false);
        TextureRegistry registry = new TextureRegistry() {
            public SurfaceTextureEntry createSurfaceTexture() { throw new AssertionError("Expected managed output."); }
            public SurfaceProducer createSurfaceProducer(SurfaceLifecycle lifecycle) { return producer; }
        };
        DisintegrateScene scene = new DisintegrateScene(configuration, registry,
            new Handler(Looper.getMainLooper()), invalidated -> invalidated.close(null));
        HandlerThread worker = HandlerThread.latest();
        try {
            require(worker.priority() == expectedPriority, "Expected particle worker priority " + expectedPriority);
        } finally {
            scene.close(null);
            worker.getLooper().drain();
            Looper.getMainLooper().drain();
        }
    }
}
