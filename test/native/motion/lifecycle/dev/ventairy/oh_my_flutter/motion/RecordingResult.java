package dev.ventairy.oh_my_flutter.motion;

import io.flutter.plugin.common.MethodChannel;

final class RecordingResult implements MethodChannel.Result {
    int successCount;
    int errorCount;
    String errorCode;

    public void success(Object response) { successCount++; }

    public void error(String code, String message, Object details) {
        errorCount++;
        errorCode = code;
    }

    public void notImplemented() { throw new AssertionError("Unexpected unimplemented method."); }
}
