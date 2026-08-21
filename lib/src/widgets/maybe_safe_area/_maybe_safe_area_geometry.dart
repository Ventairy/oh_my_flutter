part of 'maybe_safe_area.dart';

abstract final class _MaybeSafeAreaGeometry {
  static double horizontalCorrection({
    required _MaybeSafeAreaBounds bounds,
    required _MaybeSafeAreaEdges enabledEdges,
    required double viewWidth,
    required double viewHeight,
    required double viewPaddingLeft,
    required double viewPaddingRight,
  }) {
    final intersectsView = bounds.bottom > 0 && bounds.top < viewHeight;
    return _axisCorrection(
      minimum: bounds.left,
      maximum: bounds.right,
      viewMaximum: viewWidth,
      safeMinimum: viewPaddingLeft,
      safeMaximum: viewWidth - viewPaddingRight,
      avoidMinimum: enabledEdges.left && viewPaddingLeft > 0 && intersectsView,
      avoidMaximum: enabledEdges.right && viewPaddingRight > 0 && intersectsView,
    );
  }

  static double verticalCorrection({
    required _MaybeSafeAreaBounds bounds,
    required _MaybeSafeAreaEdges enabledEdges,
    required double viewWidth,
    required double viewHeight,
    required double viewPaddingTop,
    required double viewPaddingBottom,
  }) {
    final intersectsView = bounds.right > 0 && bounds.left < viewWidth;
    return _axisCorrection(
      minimum: bounds.top,
      maximum: bounds.bottom,
      viewMaximum: viewHeight,
      safeMinimum: viewPaddingTop,
      safeMaximum: viewHeight - viewPaddingBottom,
      avoidMinimum: enabledEdges.top && viewPaddingTop > 0 && intersectsView,
      avoidMaximum: enabledEdges.bottom && viewPaddingBottom > 0 && intersectsView,
    );
  }

  static double _axisCorrection({
    required double minimum,
    required double maximum,
    required double viewMaximum,
    required double safeMinimum,
    required double safeMaximum,
    required bool avoidMinimum,
    required bool avoidMaximum,
  }) {
    final overlapsMinimum = avoidMinimum && minimum < safeMinimum && maximum > 0;
    final overlapsMaximum = avoidMaximum && maximum > safeMaximum && minimum < viewMaximum;
    if (!overlapsMinimum && !overlapsMaximum) return 0;

    final span = maximum - minimum;
    final allowedMinimum = avoidMinimum ? safeMinimum : 0;
    final allowedMaximum = avoidMaximum ? safeMaximum : viewMaximum;
    final availableSpan = allowedMaximum - allowedMinimum;
    if (span > availableSpan) {
      final correctionToMaximum = allowedMaximum - maximum;
      if (correctionToMaximum > 0) return correctionToMaximum;
      final correctionToMinimum = allowedMinimum - minimum;
      if (correctionToMinimum < 0) return correctionToMinimum;
      return 0;
    }
    if (overlapsMinimum) {
      return minimum < 0 ? safeMinimum : safeMinimum - minimum;
    }
    return maximum > viewMaximum ? safeMaximum - viewMaximum : safeMaximum - maximum;
  }
}
