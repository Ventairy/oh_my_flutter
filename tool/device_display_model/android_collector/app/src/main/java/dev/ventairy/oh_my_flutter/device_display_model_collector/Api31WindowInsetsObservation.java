package dev.ventairy.oh_my_flutter.device_display_model_collector;

import android.annotation.TargetApi;
import android.app.Activity;
import android.graphics.Insets;
import android.graphics.Point;
import android.graphics.Rect;
import android.view.Display;
import android.view.DisplayCutout;
import android.view.RoundedCorner;
import android.view.View;
import android.view.WindowInsets;
import java.util.List;
import org.json.JSONObject;

/** Builds an atomic public-API observation on API 31 and newer. */
@TargetApi(31)
final class Api31WindowInsetsObservation {
  private Api31WindowInsetsObservation() {}

  static JSONObject create(
      Activity activity,
      View view,
      WindowInsets windowInsets,
      Display display,
      String nonce) throws Exception {
    Rect displayBounds = activity.getWindowManager()
        .getMaximumWindowMetrics().getBounds();
    Point realSize = new Point();
    display.getRealSize(realSize);
    if (Math.abs(displayBounds.width() - realSize.x) > 1
        || Math.abs(displayBounds.height() - realSize.y) > 1
        || Math.abs(view.getWidth() - realSize.x) > 1
        || Math.abs(view.getHeight() - realSize.y) > 1) {
      return null;
    }
    Insets systemBars = windowInsets.getInsets(WindowInsets.Type.systemBars());
    Insets systemGestures = windowInsets.getInsets(
        WindowInsets.Type.systemGestures());
    DisplayCutout cutout = windowInsets.getDisplayCutout();
    Insets waterfall = cutout == null ? Insets.NONE : cutout.getWaterfallInsets();
    int paddingLeft = Math.max(systemBars.left, Math.max(
        waterfall.left, cutout == null ? 0 : cutout.getSafeInsetLeft()));
    int paddingTop = Math.max(systemBars.top, Math.max(
        waterfall.top, cutout == null ? 0 : cutout.getSafeInsetTop()));
    int paddingRight = Math.max(systemBars.right, Math.max(
        waterfall.right, cutout == null ? 0 : cutout.getSafeInsetRight()));
    int paddingBottom = Math.max(systemBars.bottom, Math.max(
        waterfall.bottom, cutout == null ? 0 : cutout.getSafeInsetBottom()));

    Rect cutoutBounds = new Rect();
    List<Rect> boundingRects = cutout == null
        ? List.of()
        : cutout.getBoundingRects();
    for (Rect bounds : boundingRects) {
      if (!bounds.isEmpty()) {
        if (cutoutBounds.isEmpty()) {
          cutoutBounds.set(bounds);
        } else {
          cutoutBounds.union(bounds);
        }
      }
    }

    JSONObject record = new JSONObject();
    record.put("protocolVersion", 1);
    record.put("sourceKind", "android_api31_window_insets");
    record.put("nonce", nonce);
    record.put("rotation", display.getRotation());
    record.put("physicalWidth", displayBounds.width());
    record.put("physicalHeight", displayBounds.height());
    record.put("viewPhysicalWidth", view.getWidth());
    record.put("viewPhysicalHeight", view.getHeight());
    record.put("devicePixelRatio",
        activity.getResources().getDisplayMetrics().density);
    record.put("viewPaddingLeftPhysical", paddingLeft);
    record.put("viewPaddingTopPhysical", paddingTop);
    record.put("viewPaddingRightPhysical", paddingRight);
    record.put("viewPaddingBottomPhysical", paddingBottom);
    record.put("systemGestureInsetLeftPhysical", systemGestures.left);
    record.put("systemGestureInsetTopPhysical", systemGestures.top);
    record.put("systemGestureInsetRightPhysical", systemGestures.right);
    record.put("systemGestureInsetBottomPhysical", systemGestures.bottom);
    record.put("displayCutoutWidthPhysical", cutoutBounds.width());
    record.put("displayCutoutHeightPhysical", cutoutBounds.height());
    record.put("displayCutoutCount", boundingRects.stream().filter(
        bounds -> !bounds.isEmpty()).count());
    record.put("topLeftRadiusPhysical", radius(
        windowInsets, RoundedCorner.POSITION_TOP_LEFT));
    record.put("topRightRadiusPhysical", radius(
        windowInsets, RoundedCorner.POSITION_TOP_RIGHT));
    record.put("bottomRightRadiusPhysical", radius(
        windowInsets, RoundedCorner.POSITION_BOTTOM_RIGHT));
    record.put("bottomLeftRadiusPhysical", radius(
        windowInsets, RoundedCorner.POSITION_BOTTOM_LEFT));
    return record;
  }

  private static int radius(WindowInsets insets, int position) {
    RoundedCorner corner = insets.getRoundedCorner(position);
    return corner == null ? 0 : corner.getRadius();
  }
}
