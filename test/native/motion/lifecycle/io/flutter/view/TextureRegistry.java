package io.flutter.view;

import android.graphics.SurfaceTexture;
import android.view.Surface;

public interface TextureRegistry {
    SurfaceTextureEntry createSurfaceTexture();

    default SurfaceProducer createSurfaceProducer(SurfaceLifecycle lifecycle) {
        return new FakeSurfaceProducer(true);
    }

    enum SurfaceLifecycle { resetInBackground }

    interface SurfaceProducer extends TextureEntry {
        interface Callback { void onSurfaceCleanup(); }
        void setSize(int width, int height);
        Surface getSurface();
        void setCallback(Callback callback);
        boolean handlesCropAndRotation();
    }


    interface TextureEntry {
        long id();
        void release();
    }

    interface SurfaceTextureEntry extends TextureEntry {
        SurfaceTexture surfaceTexture();
        void setOnFrameConsumedListener(OnFrameConsumedListener listener);
        void setOnTrimMemoryListener(OnTrimMemoryListener listener);
    }

    interface OnFrameConsumedListener { void onFrameConsumed(); }

    interface OnTrimMemoryListener { void onTrimMemory(int level); }
}
