package android.graphics;

public final class SurfaceTexture {
    public RuntimeException sizingFailure;
    private long timestamp;
    private boolean released;

    public SurfaceTexture(int textureName) {}

    public void setDefaultBufferSize(int width, int height) {
        if (sizingFailure != null) throw sizingFailure;
    }

    public long getTimestamp() {
        if (released) throw new IllegalStateException("SurfaceTexture was released.");
        return timestamp;
    }

    public void setTimestamp(long timestamp) { this.timestamp = timestamp; }

    public void release() { released = true; }

    public boolean isReleased() { return released; }
}
