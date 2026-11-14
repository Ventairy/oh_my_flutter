package android.view;

import android.graphics.SurfaceTexture;

public final class Surface {
    private final SurfaceTexture texture;
    private boolean released;

    public Surface(SurfaceTexture texture) { this.texture = texture; }

    public boolean isValid() { return !released && !texture.isReleased(); }

    public void release() { released = true; }
}
