package io.flutter.view;

import android.graphics.SurfaceTexture;
import android.view.Surface;

public final class FakeSurfaceProducer implements TextureRegistry.SurfaceProducer {
    public int width;
    public int height;
    public int releaseCount;
    private final boolean handlesCropAndRotation;
    private final Surface surface = new Surface(new SurfaceTexture(0));
    private Callback callback;

    public FakeSurfaceProducer(boolean handlesCropAndRotation) {
        this.handlesCropAndRotation = handlesCropAndRotation;
    }

    public long id() { return 2; }
    public void setSize(int width, int height) { this.width = width; this.height = height; }
    public Surface getSurface() { return surface; }
    public void setCallback(Callback callback) { this.callback = callback; }
    public boolean handlesCropAndRotation() { return handlesCropAndRotation; }
    public void release() { releaseCount++; surface.release(); }
    public void triggerCleanup() { if (callback != null) callback.onSurfaceCleanup(); }
}
