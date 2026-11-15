package android.os;

import java.util.ArrayDeque;

public final class Looper {
    private static final Looper mainLooper = new Looper();
    private final ArrayDeque<Runnable> tasks = new ArrayDeque<>();
    private boolean quit;

    public static Looper getMainLooper() { return mainLooper; }

    boolean post(Runnable task) {
        if (quit) return false;
        tasks.add(task);
        return true;
    }

    public void drain() {
        while (!tasks.isEmpty()) tasks.remove().run();
    }

    void quitSafely() { quit = true; }

    public boolean hasQuit() { return quit; }
}
