package android.view;

import java.util.HashSet;
import java.util.Set;

public final class Choreographer {
    public interface FrameCallback { void doFrame(long frameTimeNs); }

    private final Set<FrameCallback> callbacks = new HashSet<>();

    public static Choreographer getInstance() { return new Choreographer(); }

    public void postFrameCallback(FrameCallback callback) { callbacks.add(callback); }

    public void removeFrameCallback(FrameCallback callback) { callbacks.remove(callback); }
}
