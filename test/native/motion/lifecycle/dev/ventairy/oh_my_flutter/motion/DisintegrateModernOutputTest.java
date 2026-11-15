package dev.ventairy.oh_my_flutter.motion;

import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import io.flutter.view.FakeSurfaceProducer;
import io.flutter.view.TextureRegistry;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

public final class DisintegrateModernOutputTest {
    public static void main(String[] arguments) {
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
            producer.triggerCleanup();
            worker.getLooper().drain();
            Looper.getMainLooper().drain();
            require(producer.releaseCount == 1 && !scene.containsImage(scene.textureId, 42),
                "Surface cleanup must invalidate the image and release the managed producer.");
        } finally {
            scene.close(null);
            worker.getLooper().drain();
            Looper.getMainLooper().drain();
        }
        System.out.println("Disintegrate modern output regressions passed (3 checks).");
    }

    private static void require(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
}
