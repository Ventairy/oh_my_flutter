package dev.ventairy.oh_my_flutter.device_display_model_collector;

import android.app.Activity;
import android.content.pm.FeatureInfo;
import android.graphics.Point;
import android.os.Build;
import android.os.Bundle;
import android.view.Display;
import android.view.Surface;
import android.view.View;
import android.view.WindowInsets;
import android.widget.FrameLayout;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import org.json.JSONObject;

/** Collects one public-API display observation for non-shipping model tooling. */
public final class CornerRadiusCollectorActivity extends Activity {
  private static final String OUTPUT_FILE = "device_display_record.json";
  @Override
  protected void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      Api30WindowSetup.apply(getWindow());
    }
    FrameLayout root = new FrameLayout(this);
    root.setSystemUiVisibility(View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        | View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        | View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION);
    setContentView(root);
    root.setOnApplyWindowInsetsListener((view, insets) -> {
      view.post(() -> writeObservation(view, insets));
      return insets;
    });
    root.requestApplyInsets();
  }

  private void writeObservation(View view, WindowInsets windowInsets) {
    try {
      Display display = view.getDisplay();
      if (display == null || display.getRotation() != Surface.ROTATION_0) {
        return;
      }
      if (hasFoldOrHingeFeature()) {
        return;
      }
      if ((Build.VERSION.SDK_INT >= Build.VERSION_CODES.N
              && isInMultiWindowMode())
          || (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
              && isInPictureInPictureMode())) {
        return;
      }
      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
        writeLegacyObservation(display);
        return;
      }
      JSONObject record = Api31WindowInsetsObservation.create(
          this,
          view,
          windowInsets,
          display,
          getIntent().getStringExtra("nonce"));
      if (record != null) {
        record.put("hasFoldOrHinge", false);
        record.put("protocolSourceHash", BuildConfig.COLLECTOR_SOURCE_HASH);
        writeRecord(record);
      }
    } catch (Exception ignored) {
      // The host validates the complete record and treats absence as a failure.
    }
  }

  @SuppressWarnings("deprecation")
  private void writeLegacyObservation(Display display) throws Exception {
    if (display.getDisplayId() != Display.DEFAULT_DISPLAY
        || (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && isInMultiWindowMode())
        || (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isInPictureInPictureMode())) {
      return;
    }
    int uniqueIdArray = getResources().getIdentifier(
        "config_displayUniqueIdArray", "array", "android");
    if (uniqueIdArray != 0
        && getResources().getStringArray(uniqueIdArray).length > 0) {
      return;
    }
    int defaultRadius = frameworkDimension("rounded_corner_radius");
    int topRadius = frameworkDimension("rounded_corner_radius_top");
    int bottomRadius = frameworkDimension("rounded_corner_radius_bottom");
    if (defaultRadius <= 0 && topRadius <= 0 && bottomRadius <= 0) {
      return;
    }
    int resolvedTop = topRadius > 0 ? topRadius : defaultRadius;
    int resolvedBottom = bottomRadius > 0 ? bottomRadius : defaultRadius;
    if (resolvedTop <= 0 || resolvedBottom <= 0) {
      return;
    }

    Point current = new Point();
    display.getRealSize(current);
    if (current.x <= 0 || current.y <= 0) {
      return;
    }
    double scale = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
        ? Api23DisplayScale.calculate(display, current)
        : 1.0;
    int scaledTop = (int) (resolvedTop * scale + 0.5);
    int scaledBottom = (int) (resolvedBottom * scale + 0.5);
    if (!Double.isFinite(scale) || scale <= 0 || scaledTop <= 0 || scaledBottom <= 0) {
      return;
    }

    JSONObject record = new JSONObject();
    record.put("protocolVersion", 1);
    record.put("protocolSourceHash", BuildConfig.COLLECTOR_SOURCE_HASH);
    record.put("sourceKind", "android_legacy_default_display_resource");
    record.put("nonce", getIntent().getStringExtra("nonce"));
    record.put("rotation", display.getRotation());
    record.put("physicalWidth", current.x);
    record.put("physicalHeight", current.y);
    record.put("devicePixelRatio", getResources().getDisplayMetrics().density);
    record.put("hasFoldOrHinge", false);
    record.put("topRadiusPhysical", scaledTop);
    record.put("bottomRadiusPhysical", scaledBottom);
    writeRecord(record);
  }

  private int frameworkDimension(String name) {
    try {
      int identifier = getResources().getIdentifier(name, "dimen", "android");
      return identifier == 0 ? 0 : getResources().getDimensionPixelSize(identifier);
    } catch (RuntimeException ignored) {
      return 0;
    }
  }

  private boolean hasFoldOrHingeFeature() {
    for (FeatureInfo feature : getPackageManager().getSystemAvailableFeatures()) {
      if (feature.name == null) {
        continue;
      }
      String name = feature.name.toLowerCase(Locale.ROOT);
      if (name.contains("hinge") || name.contains("fold")) {
        return true;
      }
    }
    return Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
        && Api30WindowSetup.hasHingeSensor(this);
  }

  private void writeRecord(JSONObject record) throws Exception {
    File output = new File(getFilesDir(), OUTPUT_FILE);
    try (FileOutputStream stream = new FileOutputStream(output, false)) {
      stream.write(record.toString().getBytes(StandardCharsets.UTF_8));
    }
  }
}
