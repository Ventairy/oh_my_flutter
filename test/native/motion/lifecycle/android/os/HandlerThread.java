package android.os;

public final class HandlerThread {
    private static HandlerThread latest;
    private final Looper looper = new Looper();
    private boolean started;

    public HandlerThread(String name, int priority) { latest = this; }

    public static HandlerThread latest() { return latest; }

    public void start() { started = true; }

    public boolean hasStarted() { return started; }

    public Looper getLooper() { return looper; }

    public boolean quitSafely() {
        looper.quitSafely();
        return true;
    }
}
