package dev.ventairy.oh_my_flutter.motion;

import android.graphics.SurfaceTexture;
import io.flutter.view.TextureRegistry;

final class FakeSurfaceTextureEntry implements TextureRegistry.SurfaceTextureEntry {
    final SurfaceTexture texture = new SurfaceTexture(0);
    int releaseCount;
    private TextureRegistry.OnFrameConsumedListener consumedListener;
    private TextureRegistry.OnTrimMemoryListener trimListener;

    public long id() { return 1; }

    public SurfaceTexture surfaceTexture() { return texture; }

    public void setOnFrameConsumedListener(TextureRegistry.OnFrameConsumedListener listener) {
        consumedListener = listener;
    }

    public void setOnTrimMemoryListener(TextureRegistry.OnTrimMemoryListener listener) {
        trimListener = listener;
    }

    public void release() {
        releaseCount++;
        texture.release();
    }

    void triggerFrame(long timestamp) {
        texture.setTimestamp(timestamp);
        if (consumedListener != null) consumedListener.onFrameConsumed();
    }

    void triggerTrim(int level) {
        if (trimListener != null) trimListener.onTrimMemory(level);
    }
}
