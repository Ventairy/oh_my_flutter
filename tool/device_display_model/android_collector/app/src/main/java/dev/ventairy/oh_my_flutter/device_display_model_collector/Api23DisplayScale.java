package dev.ventairy.oh_my_flutter.device_display_model_collector;

import android.annotation.TargetApi;
import android.graphics.Point;
import android.view.Display;

/** Computes runtime-equivalent display-mode scaling on API 23 and newer. */
@TargetApi(23)
final class Api23DisplayScale {
  private Api23DisplayScale() {}

  static double calculate(Display display, Point current) {
    Display.Mode maximumMode = null;
    for (Display.Mode mode : display.getSupportedModes()) {
      if (maximumMode == null
          || mode.getPhysicalWidth() > maximumMode.getPhysicalWidth()) {
        maximumMode = mode;
      }
    }
    if (maximumMode == null) {
      return Double.NaN;
    }
    int maximumShort = Math.min(
        maximumMode.getPhysicalWidth(), maximumMode.getPhysicalHeight());
    int maximumLong = Math.max(
        maximumMode.getPhysicalWidth(), maximumMode.getPhysicalHeight());
    int currentShort = Math.min(current.x, current.y);
    int currentLong = Math.max(current.x, current.y);
    return Math.min(
        (double) currentShort / maximumShort,
        (double) currentLong / maximumLong);
  }
}
