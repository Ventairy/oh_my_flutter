package dev.ventairy.oh_my_flutter.motion;

import android.view.Surface;

final class EglWindow {
    static long lastPresentedTimestamp;
    private Surface surface;

    void initialize(Surface output) { surface = output; }

    void present(long frameTimeNs) {
        if (surface == null || !surface.isValid()) throw new AssertionError("Presenting a released surface.");
        lastPresentedTimestamp = frameTimeNs;
    }

    void release() { surface = null; }
}
