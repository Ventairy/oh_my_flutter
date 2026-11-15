package dev.ventairy.oh_my_flutter.motion;

import android.os.Handler;
import android.os.Looper;

public final class DisintegrateOutputLifecycleTest {
    public static void main(String[] arguments) {
        acknowledgesThroughTheTextureRegistryOnThePlatformThread();
        ignoresAcknowledgementQueuedBeforeRelease();
        releasesSurfaceAndRegistrationOnce();
        System.out.println("DisintegrateOutput lifecycle regressions passed (3 cases).");
    }

    private static void acknowledgesThroughTheTextureRegistryOnThePlatformThread() {
        FakeSurfaceTextureEntry entry = new FakeSurfaceTextureEntry();
        long[] acknowledged = {0};
        DisintegrateOutput output = new DisintegrateOutput(() -> entry, 10, 20,
            new Handler(Looper.getMainLooper()), timestamp -> acknowledged[0] = timestamp,
            () -> { throw new AssertionError("Unexpected invalidation."); });
        try {
            output.expectFirstFrame(42);
            entry.triggerFrame(41);
            Looper.getMainLooper().drain();
            require(acknowledged[0] == 0, "Old pixels must not release the handoff.");
            entry.triggerFrame(42);
            require(acknowledged[0] == 0, "The raster callback must not invoke the consumer inline.");
            Looper.getMainLooper().drain();
            require(acknowledged[0] == 42, "The public texture callback must acknowledge on the platform queue.");
        } finally {
            output.release();
        }
    }

    private static void ignoresAcknowledgementQueuedBeforeRelease() {
        FakeSurfaceTextureEntry entry = new FakeSurfaceTextureEntry();
        int[] acknowledgements = {0};
        DisintegrateOutput output = new DisintegrateOutput(() -> entry, 10, 20,
            new Handler(Looper.getMainLooper()), timestamp -> acknowledgements[0]++, () -> {});
        output.expectFirstFrame(42);
        entry.triggerFrame(42);
        output.release();
        Looper.getMainLooper().drain();
        require(acknowledgements[0] == 0, "Release must cancel an already queued acknowledgement.");
    }

    private static void releasesSurfaceAndRegistrationOnce() {
        FakeSurfaceTextureEntry entry = new FakeSurfaceTextureEntry();
        DisintegrateOutput output = new DisintegrateOutput(() -> entry, 10, 20,
            new Handler(Looper.getMainLooper()), timestamp -> {}, () -> {});
        output.release();
        output.release();
        require(entry.releaseCount == 1 && !output.surface.isValid(), "Release must close the surface and registration once.");
    }

    private static void require(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
}
