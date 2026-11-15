package dev.ventairy.oh_my_flutter.motion;

import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

final class SceneFixture {
    final FakeSurfaceTextureEntry entry = new FakeSurfaceTextureEntry();
    final List<Map<String, Object>> preparations = new ArrayList<>();
    final List<Throwable> preparationFailures = new ArrayList<>();
    final DisintegrateScene scene;
    final HandlerThread worker;
    int invalidationCount;

    SceneFixture() {
        scene = new DisintegrateScene(configuration(), () -> entry, new Handler(Looper.getMainLooper()), invalidated -> {
            invalidationCount++;
            invalidated.close(null);
        });
        worker = HandlerThread.latest();
    }

    static DisintegrateConfiguration configuration() {
        return new DisintegrateConfiguration(Map.ofEntries(
            Map.entry("width", 2), Map.entry("height", 2),
            Map.entry("viewportWidth", 10), Map.entry("viewportHeight", 10),
            Map.entry("originX", 0), Map.entry("originY", 0),
            Map.entry("scaleX", 1), Map.entry("scaleY", 1),
            Map.entry("pointPadding", 2), Map.entry("maximumParticleCount", 4),
            Map.entry("minimumCellSize", 1), Map.entry("seed", 42),
            Map.entry("geometryParameters", new double[10]),
            Map.entry("vertexSource", "unused"), Map.entry("fragmentSource", "unused")
        ));
    }

    long prepare(long handle) {
        scene.prepareImage(new byte[16], handle, false, new double[14], preparations::add, preparationFailures::add);
        drain();
        if (!preparationFailures.isEmpty()) throw new AssertionError("Unexpected preparation failure.", preparationFailures.get(0));
        return EglWindow.lastPresentedTimestamp;
    }

    void drain() {
        Looper.getMainLooper().drain();
        worker.getLooper().drain();
        Looper.getMainLooper().drain();
    }

    void close() {
        scene.close(null);
        drain();
    }
}
