package android.os;

public final class Process {
    public static final int THREAD_PRIORITY_DISPLAY = -4;

    public static int myTid() { return 1; }

    public static int getThreadPriority(int threadId) { return THREAD_PRIORITY_DISPLAY; }
}
