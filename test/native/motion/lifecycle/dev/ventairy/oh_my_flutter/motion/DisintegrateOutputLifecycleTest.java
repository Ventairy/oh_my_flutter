package dev.ventairy.oh_my_flutter.motion;

import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import io.flutter.view.FakeSurfaceProducer;
import io.flutter.view.TextureRegistry;

public final class DisintegrateOutputLifecycleTest {
    public static void main(String[] arguments) {
        acknowledgesThroughTheTextureRegistryOnThePlatformThread();
        createsTheLegacyTextureDirectlyOnAndroidPie();
        rejectsGaussianWithACropAwareProducer();
        rejectsGaussianBeforeAllocatingOnAndroidPie();
        acknowledgesExplicitLegacyGaussianOnAndroidPie();
        ignoresAcknowledgementQueuedBeforeRelease();
        releasesSurfaceAndRegistrationOnce();
        System.out.println("DisintegrateOutput lifecycle regressions passed (7 cases).");
    }

    private static void acknowledgesThroughTheTextureRegistryOnThePlatformThread() {
        FakeSurfaceTextureEntry entry = new FakeSurfaceTextureEntry();
        long[] acknowledged = {0};
        DisintegrateOutput output = new DisintegrateOutput(() -> entry, 10, 20, false, false,
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
        DisintegrateOutput output = new DisintegrateOutput(() -> entry, 10, 20, false, false,
            new Handler(Looper.getMainLooper()), timestamp -> acknowledgements[0]++, () -> {});
        output.expectFirstFrame(42);
        entry.triggerFrame(42);
        output.release();
        Looper.getMainLooper().drain();
        require(acknowledgements[0] == 0, "Release must cancel an already queued acknowledgement.");
    }

    private static void createsTheLegacyTextureDirectlyOnAndroidPie() {
        int sdk = Build.VERSION.SDK_INT;
        Build.VERSION.SDK_INT = Build.VERSION_CODES.Q - 1;
        FakeSurfaceTextureEntry entry = new FakeSurfaceTextureEntry();
        TextureRegistry registry = new TextureRegistry() {
            @Override
            public SurfaceTextureEntry createSurfaceTexture() { return entry; }

            @Override
            public SurfaceProducer createSurfaceProducer(SurfaceLifecycle lifecycle) {
                throw new AssertionError("Legacy output does not need a producer registration.");
            }
        };
        try {
            DisintegrateOutput output = new DisintegrateOutput(registry, 10, 20, false, false,
                new Handler(Looper.getMainLooper()), timestamp -> {}, () -> {});
            try {
                require(output.textureId == entry.id() && !output.needsReadinessProbe,
                    "Android Pie must use the direct texture and consumed-frame callback.");
            } finally {
                output.release();
            }
        } finally {
            Build.VERSION.SDK_INT = sdk;
        }
    }

    private static void rejectsGaussianWithACropAwareProducer() {
        FakeSurfaceProducer producer = new FakeSurfaceProducer(true);
        TextureRegistry registry = new TextureRegistry() {
            @Override
            public SurfaceTextureEntry createSurfaceTexture() {
                throw new AssertionError("A rejected Gaussian request must leave allocation to the stock retry.");
            }

            @Override
            public SurfaceProducer createSurfaceProducer(SurfaceLifecycle lifecycle) { return producer; }
        };
        expectGaussianRejection(registry);
        require(producer.releaseCount == 1, "Rejecting the crop-aware producer must release its registration once.");
    }

    private static void rejectsGaussianBeforeAllocatingOnAndroidPie() {
        int sdk = Build.VERSION.SDK_INT;
        Build.VERSION.SDK_INT = Build.VERSION_CODES.Q - 1;
        TextureRegistry registry = new TextureRegistry() {
            @Override
            public SurfaceTextureEntry createSurfaceTexture() {
                throw new AssertionError("A rejected Gaussian request must leave allocation to the stock retry.");
            }

            @Override
            public SurfaceProducer createSurfaceProducer(SurfaceLifecycle lifecycle) {
                throw new AssertionError("Android Pie cannot negotiate a managed producer.");
            }
        };
        try {
            expectGaussianRejection(registry);
        } finally {
            Build.VERSION.SDK_INT = sdk;
        }
    }

    private static void acknowledgesExplicitLegacyGaussianOnAndroidPie() {
        int sdk = Build.VERSION.SDK_INT;
        Build.VERSION.SDK_INT = Build.VERSION_CODES.Q - 1;
        FakeSurfaceTextureEntry entry = new FakeSurfaceTextureEntry();
        TextureRegistry registry = new TextureRegistry() {
            @Override
            public SurfaceTextureEntry createSurfaceTexture() { return entry; }

            @Override
            public SurfaceProducer createSurfaceProducer(SurfaceLifecycle lifecycle) {
                throw new AssertionError("Android Pie must keep the SurfaceTexture.");
            }
        };
        long[] acknowledged = {0};
        try {
            DisintegrateOutput output = new DisintegrateOutput(registry, 10, 20, true, true,
                new Handler(Looper.getMainLooper()), timestamp -> acknowledged[0] = timestamp, () -> {});
            try {
                output.expectFirstFrame(43);
                entry.triggerFrame(42);
                Looper.getMainLooper().drain();
                require(acknowledged[0] == 0, "Replay must wait past an older prepared frame.");
                entry.triggerFrame(43);
                Looper.getMainLooper().drain();
                require(acknowledged[0] == 43 && output.width == 10 && output.height == 20
                        && !output.needsReadinessProbe,
                    "Gaussian output must have its own frame timestamp and use the full texture without a probe row.");
            } finally {
                output.release();
            }
        } finally {
            Build.VERSION.SDK_INT = sdk;
        }
    }

    private static void expectGaussianRejection(TextureRegistry registry) {
        try {
            DisintegrateOutput output = new DisintegrateOutput(registry, 10, 20, true, false,
                new Handler(Looper.getMainLooper()), timestamp -> {}, () -> {});
            output.release();
        } catch (IllegalStateException | UnsupportedOperationException expected) {
            return;
        }
        throw new AssertionError("Expected the Gaussian negotiation to fail.");
    }

    private static void releasesSurfaceAndRegistrationOnce() {
        FakeSurfaceTextureEntry entry = new FakeSurfaceTextureEntry();
        DisintegrateOutput output = new DisintegrateOutput(() -> entry, 10, 20, false, false,
            new Handler(Looper.getMainLooper()), timestamp -> {}, () -> {});
        output.release();
        output.release();
        require(entry.releaseCount == 1 && !output.surface.isValid(), "Release must close the surface and registration once.");
    }

    private static void require(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
}
