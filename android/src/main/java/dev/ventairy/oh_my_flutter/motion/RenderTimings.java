package dev.ventairy.oh_my_flutter.motion;

import android.os.Debug;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

final class RenderTimings {
    private final long requestedNs = System.nanoTime();
    private final Map<String, Object> phases = new LinkedHashMap<>();
    private final List<Long> frameTimesNs = new ArrayList<>();
    private final List<Long> drawTimesUs = new ArrayList<>();
    private final List<Long> presentTimesUs = new ArrayList<>();
    private final List<Long> drawThreadCpuUs = new ArrayList<>();
    private final List<Long> presentThreadCpuUs = new ArrayList<>();
    private long workerStartedNs;
    private long workerStartedCpuNs;

    static void phase(RenderTimings timings, String name, Runnable action) {
        if (timings == null) {
            action.run();
            return;
        }
        long startedNs = System.nanoTime();
        long startedCpuNs = Debug.threadCpuTimeNanos();
        action.run();
        Map<String, Object> values = new HashMap<>();
        values.put("threadCpuUs", (Debug.threadCpuTimeNanos() - startedCpuNs) / 1000);
        values.put("wallUs", (System.nanoTime() - startedNs) / 1000);
        timings.phases.put(name, values);
    }

    void startWorker() {
        workerStartedNs = System.nanoTime();
        workerStartedCpuNs = Debug.threadCpuTimeNanos();
    }

    void frame(long frameTimeNs, Runnable draw, Runnable present) {
        long startedNs = System.nanoTime();
        long startedCpuNs = Debug.threadCpuTimeNanos();
        draw.run();
        long drawFinishedCpuNs = Debug.threadCpuTimeNanos();
        long drawFinishedNs = System.nanoTime();
        present.run();
        long presentFinishedNs = System.nanoTime();
        long presentFinishedCpuNs = Debug.threadCpuTimeNanos();
        frameTimesNs.add(frameTimeNs);
        drawTimesUs.add((drawFinishedNs - startedNs) / 1000);
        presentTimesUs.add((presentFinishedNs - drawFinishedNs) / 1000);
        drawThreadCpuUs.add((drawFinishedCpuNs - startedCpuNs) / 1000);
        presentThreadCpuUs.add((presentFinishedCpuNs - drawFinishedCpuNs) / 1000);
    }

    Map<String, Object> preparation(boolean sceneReused) {
        Map<String, Object> values = new HashMap<>();
        values.put("setupUs", (System.nanoTime() - requestedNs) / 1000);
        values.put("queueWaitUs", (workerStartedNs - requestedNs) / 1000);
        values.put("setupThreadCpuUs", (Debug.threadCpuTimeNanos() - workerStartedCpuNs) / 1000);
        values.put("sceneReused", sceneReused);
        values.put("preparePhases", new LinkedHashMap<>(phases));
        return values;
    }

    Map<String, Object> playback(long startNs, long finishNs, long completedNs) {
        Map<String, Object> values = new HashMap<>();
        values.put("startNs", startNs);
        values.put("finishNs", finishNs);
        values.put("completedNs", completedNs);
        values.put("frameTimesNs", frameTimesNs);
        values.put("drawTimesUs", drawTimesUs);
        values.put("presentTimesUs", presentTimesUs);
        values.put("drawThreadCpuUs", drawThreadCpuUs);
        values.put("presentThreadCpuUs", presentThreadCpuUs);
        return values;
    }
}
