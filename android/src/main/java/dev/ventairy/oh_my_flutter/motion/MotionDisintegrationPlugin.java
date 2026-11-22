package dev.ventairy.oh_my_flutter.motion;

import android.os.Handler;
import android.os.Looper;
import java.util.HashMap;
import java.util.Map;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.view.TextureRegistry;

public final class MotionDisintegrationPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private TextureRegistry textureRegistry;
    private MethodChannel channel;
    private final Map<Long, DisintegrateScene> scenes = new HashMap<>();
    private long nextHandle;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        textureRegistry = binding.getTextureRegistry();
        channel = new MethodChannel(binding.getBinaryMessenger(), "dev.ventairy.oh_my_flutter.motion");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
        textureRegistry = null;
        releaseAllScenes();
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (call.method.equals("supportsManagedGaussian")) {
            result.success(DisintegrateOutput.supportsManagedOutput());
            return;
        }
        if (call.method.equals("releaseRenderer")) {
            Long instance = call.arguments instanceof Map<?, ?> values && values.get("instanceId") instanceof Number id ? id.longValue() : null;
            if (instance == null) {
                releaseAllScenes();
                result.success(null);
                return;
            }
            releaseInstance(instance, () -> result.success(null));
            return;
        }
        if (!(call.arguments instanceof Map<?, ?> arguments)) {
            result.error("invalid_arguments", "Expected named arguments.", null);
            return;
        }
        try {
            if (call.method.equals("prepare")) {
                prepare(arguments, result);
                return;
            }
            long textureId = ((Number) arguments.get("textureId")).longValue();
            long handle = ((Number) arguments.get("handle")).longValue();
            long instance = ((Number) arguments.get("instanceId")).longValue();
            DisintegrateScene current = scenes.get(instance);
            if (current == null || !current.containsImage(textureId, handle)) {
                if (call.method.equals("dispose")) {
                    result.success(null);
                    return;
                }
                result.error("replaced", "The disintegration was replaced.", null);
                return;
            }
            switch (call.method) {
                case "awaitFirstFrame":
                    current.awaitFirstFrame(result);
                    return;
                case "play":
                    double fromProgress = arguments.get("fromProgress") instanceof Number value ? value.doubleValue() : 0;
                    long durationMillis = ((Number) arguments.get("durationMillis")).longValue();
                    if (!Double.isFinite(fromProgress) || fromProgress < 0 || fromProgress > 1
                            || durationMillis <= 0 || durationMillis > Long.MAX_VALUE / 1000000L) {
                        throw new IllegalArgumentException("Expected progress from zero to one and a positive duration.");
                    }
                    current.play(fromProgress, durationMillis, Boolean.TRUE.equals(arguments.get("collectTimings")),
                        Boolean.TRUE.equals(arguments.get("collectFrameCount")), result);
                    return;
                case "setFrame":
                    current.setFrame((double[]) arguments.get("frame"), result);
                    return;
                case "pause":
                    current.pause(result);
                    return;
                case "dispose":
                    current.releaseImage(Boolean.TRUE.equals(arguments.get("retainOutput")), result);
                    return;
                default:
                    result.notImplemented();
            }
        } catch (RuntimeException error) {
            result.error("invalid_arguments", error.getMessage(), null);
        }
    }

    private void prepare(Map<?, ?> arguments, MethodChannel.Result result) {
        if (textureRegistry == null) {
            result.error("disposed", "The engine was detached.", null);
            return;
        }
        DisintegrateConfiguration configuration = new DisintegrateConfiguration(arguments);
        if (!(arguments.get("image") instanceof byte[] pixels)) {
            throw new IllegalArgumentException("Expected RGBA image bytes.");
        }
        long instance = ((Number) arguments.get("instanceId")).longValue();
        DisintegrateScene current = scenes.get(instance);
        if (current == null || !current.matches(configuration)) {
            releaseInstance(instance, null);
            current = new DisintegrateScene(configuration, textureRegistry, mainHandler, this::invalidateScene);
            scenes.put(instance, current);
        }
        final DisintegrateScene prepared = current;
        long handle = ++nextHandle;
        current.prepareImage(pixels, handle, Boolean.TRUE.equals(arguments.get("collectTimings")), (double[]) arguments.get("frame"), response -> {
            if (scenes.get(instance) != prepared || !prepared.containsImage(prepared.textureId, handle)) {
                result.error("replaced", "The disintegration was replaced.", null);
                return;
            }
            result.success(response);
        }, error -> {
            if (scenes.get(instance) == prepared && prepared.containsImage(prepared.textureId, handle)) releaseInstance(instance, null);
            result.error("prepare_failed", error.getMessage(), null);
        });
    }

    private void invalidateScene(DisintegrateScene invalidated) {
        scenes.values().removeIf(value -> value == invalidated);
        invalidated.close(null);
    }

    private void releaseInstance(long instance, Runnable onReleased) {
        DisintegrateScene current = scenes.remove(instance);
        if (current != null) {
            current.close(onReleased);
            return;
        }
        if (onReleased != null) onReleased.run();
    }

    private void releaseAllScenes() {
        DisintegrateScene[] closing = scenes.values().toArray(new DisintegrateScene[0]);
        scenes.clear();
        for (DisintegrateScene current : closing) current.close(null);
    }
}
