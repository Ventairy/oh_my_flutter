package dev.ventairy.oh_my_flutter.motion;

import java.util.HashMap;
import java.util.Map;

final class ParticleRenderer {
    static final int READINESS_PROBE_WIDTH = 22;
    static long lastProbedHandle;
    private boolean released;

    ParticleRenderer(DisintegrateConfiguration configuration) {}

    void initialize(RenderTimings timings) {}

    void uploadImage(byte[] pixels) {}

    void draw(float progress) {
        if (released) throw new AssertionError("Drawing a released renderer.");
    }

    Map<String, Object> capabilities() { return new HashMap<>(); }

    void setFrame(double[] frame) {}

    void drawReadinessProbe(long handle) { lastProbedHandle = handle; }

    void releaseImage() {}

    void release() { released = true; }
}
