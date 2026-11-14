package dev.ventairy.oh_my_flutter.motion;

import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;

public final class DisintegrateSceneLifecycleTest {
    public static void main(String[] arguments) {
        closesBeforeWorkerPreparationAndKeepsReplacementUsable();
        releasesRegistrationWhenInitialSurfaceCreationFails();
        waitsForPreparedSourceTimestamp();
        acceptsConsumptionBeforeAwait();
        waitsPastCachedTransparentFrame();
        replacementRejectsPendingAwait();
        closeRejectsPendingAwait();
        imageDisposalRejectsPendingAwait();
        memoryPressureRejectsPendingAwait();
        pausesWithoutDisposingThePreparedImage();
        updatesAComposedFrameWithoutReplacingItsScene();
        rejectsImageHandlesAfterReplacementAndClose();
        System.out.println("DisintegrateScene lifecycle regressions passed (12 cases).");
    }

    private static void rejectsImageHandlesAfterReplacementAndClose() {
        SceneFixture fixture = new SceneFixture();
        fixture.prepare(1);
        require(fixture.scene.containsImage(fixture.scene.textureId, 1), "The scene must recognize its prepared image.");
        fixture.prepare(2);
        require(!fixture.scene.containsImage(fixture.scene.textureId, 1), "Replacing pixels must invalidate the earlier handle.");
        require(!fixture.scene.containsImage(fixture.scene.textureId + 1, 2), "A handle must match its native texture.");
        require(fixture.scene.containsImage(fixture.scene.textureId, 2), "The current image must remain valid.");
        fixture.close();
        require(!fixture.scene.containsImage(fixture.scene.textureId, 2), "Closing the scene must invalidate its image handle.");
    }

    private static void pausesWithoutDisposingThePreparedImage() {
        SceneFixture fixture = new SceneFixture();
        fixture.prepare(1);
        RecordingResult playback = new RecordingResult();
        fixture.scene.play(0, 2000, false, false, playback);
        fixture.drain();
        RecordingResult pause = new RecordingResult();
        fixture.scene.pause(pause);
        fixture.drain();
        require(playback.successCount == 1 && pause.successCount == 1, "Pause must complete the native run without reporting failure.");
        require(fixture.entry.releaseCount == 0, "Pause must keep the native surface registered.");
        RecordingResult resume = new RecordingResult();
        fixture.scene.play(0.4, 1200, false, false, resume);
        fixture.drain();
        require(resume.errorCount == 0, "The same prepared image must support resuming.");
        fixture.close();
    }

    private static void updatesAComposedFrameWithoutReplacingItsScene() {
        SceneFixture fixture = new SceneFixture();
        fixture.prepare(1);
        RecordingResult update = new RecordingResult();
        double[] values = new double[14];
        values[0] = 0.3;
        fixture.scene.setFrame(values, update);
        fixture.drain();
        require(update.successCount == 1 && update.errorCount == 0, "A driven frame must render through the existing scene.");
        require(fixture.entry.releaseCount == 0, "Updating parameters must not replace the native surface.");
        fixture.close();
    }

    private static void closesBeforeWorkerPreparationAndKeepsReplacementUsable() {
        SceneFixture original = new SceneFixture();
        original.scene.prepareImage(new byte[16], 1, false, new double[14],
            original.preparations::add, original.preparationFailures::add);
        int[] releaseCallbacks = {0};

        // Nothing on the worker has run: the output must still release safely.
        original.scene.close(() -> releaseCallbacks[0]++);
        require(original.entry.releaseCount == 1, "Close must release the entry immediately.");
        require(!original.worker.getLooper().hasQuit(), "Worker cleanup must remain queued.");
        original.drain();
        require(original.worker.getLooper().hasQuit(), "Close must quit the worker after cleanup.");
        require(releaseCallbacks[0] == 1, "Close must complete once.");
        require(original.preparations.isEmpty(), "A closed pending preparation must not succeed.");
        require(original.preparationFailures.size() == 1, "A closed pending preparation must report disposal.");

        SceneFixture replacement = new SceneFixture();
        replacement.prepare(2);
        require(replacement.preparations.size() == 1, "A later scene must prepare successfully.");

        original.scene.close(() -> releaseCallbacks[0]++);
        RecordingResult progressResult = new RecordingResult();
        double[] frame = new double[14];
        frame[0] = 0.35;
        replacement.scene.setFrame(frame, progressResult);
        replacement.drain();
        require(progressResult.successCount == 1 && progressResult.errorCode == null,
            "A stale close must leave the replacement usable.");
        require(original.entry.releaseCount == 1, "Repeated close must not release the old entry again.");
        require(replacement.entry.releaseCount == 0, "A stale close must not release the new entry.");

        replacement.scene.close(() -> releaseCallbacks[0]++);
        replacement.drain();
        require(replacement.worker.getLooper().hasQuit(), "Replacement cleanup must quit its worker.");
        require(releaseCallbacks[0] == 3, "Every close callback must complete.");
    }

    private static void releasesRegistrationWhenInitialSurfaceCreationFails() {
        FakeSurfaceTextureEntry entry = new FakeSurfaceTextureEntry();
        RuntimeException creationFailure = new IllegalStateException("Surface creation failed.");
        entry.texture.sizingFailure = creationFailure;
        try {
            new DisintegrateScene(SceneFixture.configuration(), () -> entry, new Handler(Looper.getMainLooper()),
                scene -> { throw new AssertionError("Unexpected failed-scene invalidation."); });
            throw new AssertionError("Construction must report the surface creation failure.");
        } catch (RuntimeException error) {
            require(error == creationFailure, "Cleanup must preserve the original creation failure.");
        }
        require(entry.releaseCount == 1, "Failed construction must release the texture registration.");
        require(!HandlerThread.latest().hasStarted(), "Failed construction must not start the worker.");
    }

    private static void waitsForPreparedSourceTimestamp() {
        SceneFixture fixture = new SceneFixture();
        long expectedTimestamp = fixture.prepare(1);
        RecordingResult result = new RecordingResult();
        fixture.scene.awaitFirstFrame(result);
        fixture.drain();
        require(result.successCount == 0 && result.errorCount == 0, "Submission alone must not acknowledge consumption.");
        fixture.entry.triggerFrame(expectedTimestamp - 1);
        fixture.drain();
        require(result.successCount == 0 && result.errorCount == 0, "An older consumed frame must not acknowledge the source.");
        fixture.entry.triggerFrame(expectedTimestamp);
        fixture.drain();
        require(result.successCount == 1 && result.errorCount == 0, "The prepared source consumption must acknowledge readiness.");
        fixture.entry.triggerFrame(expectedTimestamp + 1);
        fixture.drain();
        require(result.successCount == 1, "Consumption must acknowledge each preparation only once.");
        fixture.close();
    }

    private static void acceptsConsumptionBeforeAwait() {
        SceneFixture fixture = new SceneFixture();
        fixture.entry.triggerFrame(fixture.prepare(1));
        fixture.drain();
        RecordingResult result = new RecordingResult();
        fixture.scene.awaitFirstFrame(result);
        fixture.drain();
        require(result.successCount == 1 && result.errorCount == 0, "Already consumed source pixels must acknowledge immediately.");
        fixture.close();
    }

    private static void waitsPastCachedTransparentFrame() {
        SceneFixture fixture = new SceneFixture();
        fixture.prepare(1);
        RecordingResult disposal = new RecordingResult();
        fixture.scene.releaseImage(disposal);
        fixture.drain();
        require(disposal.successCount == 1, "Image disposal must finish before reuse.");
        long transparentTimestamp = EglWindow.lastPresentedTimestamp;
        long expectedTimestamp = fixture.prepare(2);
        require(expectedTimestamp > transparentTimestamp, "A reused source must have a fresh presentation timestamp.");
        RecordingResult result = new RecordingResult();
        fixture.scene.awaitFirstFrame(result);
        fixture.drain();
        fixture.entry.triggerFrame(transparentTimestamp);
        fixture.drain();
        require(result.successCount == 0 && result.errorCount == 0, "A cached transparent frame must not release the handoff.");
        fixture.entry.triggerFrame(expectedTimestamp);
        fixture.drain();
        require(result.successCount == 1, "The new post must release the handoff after its own frame is consumed.");
        fixture.close();
    }

    private static void replacementRejectsPendingAwait() {
        SceneFixture fixture = new SceneFixture();
        fixture.prepare(1);
        RecordingResult replaced = new RecordingResult();
        fixture.scene.awaitFirstFrame(replaced);
        fixture.drain();
        long replacementTimestamp = fixture.prepare(2);
        require(replaced.errorCount == 1 && "replaced".equals(replaced.errorCode), "Replacing pixels must reject the old wait.");
        RecordingResult replacement = new RecordingResult();
        fixture.scene.awaitFirstFrame(replacement);
        fixture.drain();
        fixture.entry.triggerFrame(replacementTimestamp);
        fixture.drain();
        require(replacement.successCount == 1 && replacement.errorCount == 0, "Replacement consumption must acknowledge its own wait.");
        fixture.close();
    }

    private static void closeRejectsPendingAwait() {
        SceneFixture fixture = new SceneFixture();
        long timestamp = fixture.prepare(1);
        RecordingResult result = new RecordingResult();
        fixture.scene.awaitFirstFrame(result);
        fixture.drain();
        fixture.close();
        fixture.entry.triggerFrame(timestamp);
        fixture.drain();
        require(result.errorCount == 1 && "disposed".equals(result.errorCode), "Closing must reject a pending consumption wait.");
        require(result.successCount == 0, "A consumed callback after close must not complete a rejected wait.");
        require(fixture.worker.getLooper().hasQuit(), "Closing must quit the worker with a pending wait.");
    }

    private static void imageDisposalRejectsPendingAwait() {
        SceneFixture fixture = new SceneFixture();
        fixture.prepare(1);
        RecordingResult result = new RecordingResult();
        fixture.scene.awaitFirstFrame(result);
        fixture.drain();
        RecordingResult disposal = new RecordingResult();
        fixture.scene.releaseImage(disposal);
        fixture.drain();
        require(result.errorCount == 1 && "disposed".equals(result.errorCode), "Disposing pixels must reject their pending wait.");
        require(disposal.successCount == 1, "The disposal request must still complete.");
        fixture.close();
    }

    private static void memoryPressureRejectsPendingAwait() {
        SceneFixture fixture = new SceneFixture();
        fixture.prepare(1);
        RecordingResult result = new RecordingResult();
        fixture.scene.awaitFirstFrame(result);
        fixture.drain();
        fixture.entry.triggerTrim(39);
        fixture.drain();
        require(fixture.invalidationCount == 0, "Foreground pressure must not invalidate this background-cleanup output.");
        fixture.entry.triggerTrim(40);
        fixture.drain();
        require(fixture.invalidationCount == 1, "Background pressure must invalidate the scene.");
        require(fixture.entry.releaseCount == 1, "Invalidation must release the texture entry.");
        require(result.errorCount == 1 && "disposed".equals(result.errorCode), "Invalidation must reject pending consumption.");
        require(fixture.worker.getLooper().hasQuit(), "Invalidation must finish worker cleanup.");
    }

    private static void require(boolean condition, String message) {
        if (!condition) throw new AssertionError(message);
    }
}
