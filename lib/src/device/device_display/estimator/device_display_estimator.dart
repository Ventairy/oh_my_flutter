import 'dart:math' as math;

import 'package:flutter/widgets.dart';

part 'device_display_estimator_model.g.dart';
part 'device_display_metrics.dart';
part 'device_display_platform_kind.dart';

/// Estimates display corner radii when the platform does not report them.
///
/// Prefer an exact value supplied by Flutter. This estimator is intended only
/// as a fallback and can differ from the physical display on unfamiliar
/// hardware.
abstract final class DeviceDisplayEstimator {
  /// Returns a bounded corner-radius estimate for [metrics].
  ///
  /// The result uses logical pixels. It is `null` only when the supplied
  /// metrics are non-finite, non-positive, folded, or otherwise unusable.
  /// Valid but unfamiliar phone-shaped geometry receives a conservative
  /// extrapolation.
  static BorderRadius? estimate(DeviceDisplayMetrics metrics) {
    assert(
      _DeviceDisplayEstimatorModel.hasCandidateKinds,
      'The generated estimator must identify both selected candidates.',
    );
    if (!_areMetricsUsable(metrics)) {
      return null;
    }

    final displayShortSide = math.min(
      metrics.displaySize.width,
      metrics.displaySize.height,
    );
    final displayLongSide = math.max(
      metrics.displaySize.width,
      metrics.displaySize.height,
    );
    final isIos = metrics.platformKind == DeviceDisplayPlatformKind.ios;
    final isLandscape = metrics.displaySize.width > metrics.displaySize.height;
    final naturalTopIsTrailing = _naturalTopIsTrailing(
      metrics,
      isLandscape: isLandscape,
    );
    final leadingPadding = _naturalEdgePadding(
      metrics.viewPadding,
      isLandscape: isLandscape,
      trailing: false,
    );
    final trailingPadding = _naturalEdgePadding(
      metrics.viewPadding,
      isLandscape: isLandscape,
      trailing: true,
    );
    final naturalTopPadding = isIos
        ? math.max(leadingPadding, trailingPadding)
        : naturalTopIsTrailing
        ? trailingPadding
        : leadingPadding;
    final naturalBottomPadding = isIos
        ? math.min(leadingPadding, trailingPadding)
        : naturalTopIsTrailing
        ? leadingPadding
        : trailingPadding;
    final flutterSheetSafeInsetDiameter = _safeInsetDiameter(
      naturalTopPadding,
      displayShortSide: displayShortSide,
    );
    final features = _featureVector(
      metrics,
      displayShortSide: displayShortSide,
      displayLongSide: displayLongSide,
      isLandscape: isLandscape,
      naturalTopPadding: naturalTopPadding,
      naturalBottomPadding: naturalBottomPadding,
    );

    if (metrics.platformKind == DeviceDisplayPlatformKind.ios) {
      final normalizedDiameter = _DeviceDisplayEstimatorModel.iosPipelineNormalizedDiameter(
        features,
        safeInsetDiameter: flutterSheetSafeInsetDiameter,
        shortestLogicalSide: displayShortSide,
      );
      final radius = _diameterToRadius(
        normalizedDiameter,
        displayShortSide: displayShortSide,
      );
      return BorderRadius.all(Radius.circular(radius));
    }

    final topRadius = _diameterToRadius(
      _DeviceDisplayEstimatorModel.androidTopPipelineNormalizedDiameter(
        features,
        safeInsetDiameter: flutterSheetSafeInsetDiameter,
        shortestLogicalSide: displayShortSide,
      ),
      displayShortSide: displayShortSide,
    );
    final bottomRadius = _diameterToRadius(
      _DeviceDisplayEstimatorModel.androidBottomPipelineNormalizedDiameter(
        features,
        safeInsetDiameter: flutterSheetSafeInsetDiameter,
        shortestLogicalSide: displayShortSide,
      ),
      displayShortSide: displayShortSide,
    );
    return _androidBorderRadius(
      naturalTopRadius: topRadius,
      naturalBottomRadius: bottomRadius,
      isLandscape: isLandscape,
      naturalTopIsTrailing: naturalTopIsTrailing,
    );
  }

  static List<double> _featureVector(
    DeviceDisplayMetrics metrics, {
    required double displayShortSide,
    required double displayLongSide,
    required bool isLandscape,
    required double naturalTopPadding,
    required double naturalBottomPadding,
  }) {
    final displayArea = metrics.displaySize.width * metrics.displaySize.height;
    final viewArea = metrics.viewSize.width * metrics.viewSize.height;
    final isIos = metrics.platformKind == DeviceDisplayPlatformKind.ios;
    final cutout = isIos ? null : metrics.displayCutoutBounds;
    final naturalCutoutWidth = cutout == null
        ? 0.0
        : isLandscape
        ? cutout.height
        : cutout.width;
    final naturalCutoutHeight = cutout == null
        ? 0.0
        : isLandscape
        ? cutout.width
        : cutout.height;
    return <double>[
      math.log(displayLongSide / displayShortSide),
      math.log(displayShortSide * metrics.devicePixelRatio),
      math.log(displayShortSide),
      math.log(metrics.devicePixelRatio),
      viewArea / displayArea,
      2 * _maximumEdge(metrics.viewPadding) / displayShortSide,
      2 * naturalTopPadding / displayShortSide,
      2 * naturalBottomPadding / displayShortSide,
      2 * _maximumEdge(isIos ? EdgeInsets.zero : metrics.systemGestureInsets) / displayShortSide,
      naturalCutoutWidth / displayShortSide,
      naturalCutoutHeight / displayShortSide,
      (isIos ? 0.0 : metrics.displayCutoutCount / 4).clamp(0, 1),
      0,
      0,
      0,
      if (isIos) 1.0 else 0.0,
      if (isIos) 1.0 else 0.0,
    ];
  }

  static double _safeInsetDiameter(
    double logicalInset, {
    required double displayShortSide,
  }) {
    final radius = logicalInset * _DeviceDisplayEstimatorModel.safeInsetMultiplier;
    return radius > 20 ? 2 * radius / displayShortSide : 0;
  }

  static double _diameterToRadius(
    double normalizedDiameter, {
    required double displayShortSide,
  }) {
    final boundedDiameter = normalizedDiameter.isFinite ? normalizedDiameter.clamp(0, 1) : 0.0;
    return boundedDiameter * displayShortSide / 2;
  }

  static bool _naturalTopIsTrailing(
    DeviceDisplayMetrics metrics, {
    required bool isLandscape,
  }) {
    if (metrics.platformKind == DeviceDisplayPlatformKind.ios) {
      return false;
    }
    final cutout = metrics.displayCutoutBounds;
    if (cutout == null || cutout.isEmpty) {
      return false;
    }
    if (isLandscape) {
      return cutout.center.dx > metrics.viewSize.width / 2;
    }
    return cutout.center.dy > metrics.viewSize.height / 2;
  }

  static double _naturalEdgePadding(
    EdgeInsets insets, {
    required bool isLandscape,
    required bool trailing,
  }) {
    if (isLandscape) {
      return trailing ? insets.right : insets.left;
    }
    return trailing ? insets.bottom : insets.top;
  }

  static BorderRadius _androidBorderRadius({
    required double naturalTopRadius,
    required double naturalBottomRadius,
    required bool isLandscape,
    required bool naturalTopIsTrailing,
  }) {
    final top = Radius.circular(naturalTopRadius);
    final bottom = Radius.circular(naturalBottomRadius);
    if (!isLandscape) {
      return naturalTopIsTrailing
          ? BorderRadius.only(
              topLeft: bottom,
              topRight: bottom,
              bottomLeft: top,
              bottomRight: top,
            )
          : BorderRadius.only(
              topLeft: top,
              topRight: top,
              bottomLeft: bottom,
              bottomRight: bottom,
            );
    }
    return naturalTopIsTrailing
        ? BorderRadius.only(
            topLeft: bottom,
            bottomLeft: bottom,
            topRight: top,
            bottomRight: top,
          )
        : BorderRadius.only(
            topLeft: top,
            bottomLeft: top,
            topRight: bottom,
            bottomRight: bottom,
          );
  }

  static bool _areMetricsUsable(DeviceDisplayMetrics metrics) {
    final values = <double>[
      metrics.displaySize.width,
      metrics.displaySize.height,
      metrics.viewSize.width,
      metrics.viewSize.height,
      metrics.devicePixelRatio,
      metrics.viewPadding.left,
      metrics.viewPadding.top,
      metrics.viewPadding.right,
      metrics.viewPadding.bottom,
      metrics.systemGestureInsets.left,
      metrics.systemGestureInsets.top,
      metrics.systemGestureInsets.right,
      metrics.systemGestureInsets.bottom,
      if (metrics.displayCutoutBounds case final bounds?) ...[
        bounds.left,
        bounds.top,
        bounds.right,
        bounds.bottom,
      ],
    ];
    if (values.any((value) => !value.isFinite || value < 0) || metrics.devicePixelRatio == 0) {
      return false;
    }
    final logicalPixelTolerance = 1 / metrics.devicePixelRatio;
    return metrics.displaySize.width > 0 &&
        metrics.displaySize.height > 0 &&
        metrics.viewSize.width > 0 &&
        metrics.viewSize.height > 0 &&
        metrics.viewSize.width <= metrics.displaySize.width + logicalPixelTolerance &&
        metrics.viewSize.height <= metrics.displaySize.height + logicalPixelTolerance &&
        metrics.displayCutoutCount >= 0 &&
        !metrics.hasFoldOrHinge;
  }

  static double _maximumEdge(EdgeInsets insets) => math.max(
    math.max(insets.left, insets.top),
    math.max(insets.right, insets.bottom),
  );
}
