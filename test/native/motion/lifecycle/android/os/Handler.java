package android.os;

public final class Handler {
    private final Looper looper;

    public Handler(Looper looper) { this.looper = looper; }

    public boolean post(Runnable task) { return looper.post(task); }
}
