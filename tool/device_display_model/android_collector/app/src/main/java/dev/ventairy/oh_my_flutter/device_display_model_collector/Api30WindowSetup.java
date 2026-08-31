package dev.ventairy.oh_my_flutter.device_display_model_collector;

import android.annotation.TargetApi;
import android.content.Context;
import android.content.pm.PackageManager;
import android.hardware.Sensor;
import android.hardware.SensorManager;
import android.view.Window;

/** Contains API-30-only window setup so legacy runtimes never verify it. */
@TargetApi(30)
final class Api30WindowSetup {
  private Api30WindowSetup() {}

  static void apply(Window window) {
    window.setDecorFitsSystemWindows(false);
  }

  static boolean hasHingeSensor(Context context) {
    if (context.getPackageManager().hasSystemFeature(
        PackageManager.FEATURE_SENSOR_HINGE_ANGLE)) {
      return true;
    }
    SensorManager sensors = context.getSystemService(SensorManager.class);
    return sensors != null
        && sensors.getDefaultSensor(Sensor.TYPE_HINGE_ANGLE) != null;
  }
}
