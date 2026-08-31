import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'device_display_platform.dart';
import 'device_display_platform_corner_radii.dart';
import 'estimator/device_display_estimator.dart';

part 'device_display_metrics_epoch.dart';

/// Provides information about and interaction with the device display.
///
/// Use this utility directly when only display information is needed, or
/// access it through `Device().display` alongside other device utilities.
///
/// See the [device display guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/utilities/device_display.md)
/// for current display capabilities and their constraints.
interface class DeviceDisplay {
  /// Creates a utility for working with device-display capabilities.
  const DeviceDisplay();

  static const _maximumAndroidRequestCacheEntries = 8;
  static final Map<Object, Future<DeviceDisplayPlatformCornerRadii?>> _pendingAndroidRequests = {};
  static final Map<Object, DeviceDisplayPlatformCornerRadii> _completedAndroidRequests = {};

  /// Returns the current display corner radii in logical pixels.
  ///
  /// The exact value supplied by Flutter is returned whenever it is available,
  /// including [BorderRadius.zero]. When Flutter does not supply a value and
  /// [estimate] is false, this method returns null.
  ///
  /// Set [estimate] to true to allow supported Android display evidence and an
  /// approximate fallback for an iOS or Android phone. Estimation can differ
  /// from the physical display contour. A non-phone display returns null unless
  /// Flutter or Android supplies usable corner data.
  Future<BorderRadius?> cornerRadii(
    BuildContext context, {
    bool estimate = false,
  }) {
    final view = View.maybeOf(context);
    final exact = MediaQuery.maybeDisplayCornerRadiiOf(context) ?? _exactCornerRadiiFromView(view);
    if (exact != null || !estimate) return Future<BorderRadius?>.value(exact);

    final snapshot = _captureSnapshot(view);
    if (snapshot == null) return Future<BorderRadius?>.value();

    return _estimatedCornerRadii(
      snapshot.metrics,
      displayId: snapshot.displayId,
      viewId: snapshot.viewId,
      metricsEpoch: snapshot.metricsEpoch,
      displayFeaturesKey: snapshot.displayFeaturesKey,
      hasSinglePlatformView: snapshot.hasSinglePlatformView,
    );
  }

  static Future<BorderRadius?> _estimatedCornerRadii(
    DeviceDisplayMetrics metrics, {
    required int displayId,
    required int viewId,
    required int metricsEpoch,
    required String displayFeaturesKey,
    required bool hasSinglePlatformView,
  }) async {
    if (metrics.platformKind == DeviceDisplayPlatformKind.android && hasSinglePlatformView) {
      final platformRadii = await _androidCornerRadii(
        metrics,
        displayId: displayId,
        viewId: viewId,
        metricsEpoch: metricsEpoch,
        displayFeaturesKey: displayFeaturesKey,
      );
      final logicalRadii = _logicalCornerRadii(
        platformRadii,
        metrics: metrics,
      );
      if (logicalRadii != null) return logicalRadii;
    }

    if (!_isPhone(metrics)) return null;
    return DeviceDisplayEstimator.estimate(metrics);
  }

  static BorderRadius? _exactCornerRadiiFromView(ui.FlutterView? view) {
    if (view == null) return null;

    final radii = view.displayCornerRadii;
    final devicePixelRatio = view.devicePixelRatio;
    if (radii == null || !_isPositiveFinite(devicePixelRatio)) return null;

    return BorderRadius.only(
      topLeft: Radius.circular(radii.topLeft / devicePixelRatio),
      topRight: Radius.circular(radii.topRight / devicePixelRatio),
      bottomRight: Radius.circular(radii.bottomRight / devicePixelRatio),
      bottomLeft: Radius.circular(radii.bottomLeft / devicePixelRatio),
    );
  }

  static ({
    DeviceDisplayMetrics metrics,
    int displayId,
    int viewId,
    int metricsEpoch,
    String displayFeaturesKey,
    bool hasSinglePlatformView,
  })?
  _captureSnapshot(ui.FlutterView? view) {
    final platformKind = _platformKind;
    if (view == null || platformKind == null) return null;

    final devicePixelRatio = view.devicePixelRatio;
    final displayPhysicalSize = view.display.size;
    final viewPhysicalSize = view.physicalSize;
    if (!_isPositiveFinite(devicePixelRatio) ||
        !_isUsableSize(displayPhysicalSize) ||
        !_isUsableSize(viewPhysicalSize)) {
      return null;
    }
    if (viewPhysicalSize.width > displayPhysicalSize.width + 1 ||
        viewPhysicalSize.height > displayPhysicalSize.height + 1) {
      return null;
    }

    Rect? displayCutoutBounds;
    var displayCutoutCount = 0;
    var hasFoldOrHinge = false;
    final displayFeaturesKey = StringBuffer();
    for (final feature in view.displayFeatures) {
      displayFeaturesKey
        ..write(feature.type.index)
        ..write(':')
        ..write(feature.state.index)
        ..write(':')
        ..write(feature.bounds.left)
        ..write(',')
        ..write(feature.bounds.top)
        ..write(',')
        ..write(feature.bounds.right)
        ..write(',')
        ..write(feature.bounds.bottom)
        ..write(';');
      if (feature.type == ui.DisplayFeatureType.fold || feature.type == ui.DisplayFeatureType.hinge) {
        hasFoldOrHinge = true;
        continue;
      }
      if (feature.type != ui.DisplayFeatureType.cutout) continue;

      displayCutoutCount += 1;
      displayCutoutBounds = displayCutoutBounds == null
          ? feature.bounds
          : displayCutoutBounds.expandToInclude(feature.bounds);
    }

    return (
      metrics: DeviceDisplayMetrics(
        platformKind: platformKind,
        displaySize: displayPhysicalSize / devicePixelRatio,
        viewSize: viewPhysicalSize / devicePixelRatio,
        devicePixelRatio: devicePixelRatio,
        viewPadding: EdgeInsets.fromViewPadding(
          view.viewPadding,
          devicePixelRatio,
        ),
        systemGestureInsets: EdgeInsets.fromViewPadding(
          view.systemGestureInsets,
          devicePixelRatio,
        ),
        displayCutoutBounds: displayCutoutBounds,
        displayCutoutCount: displayCutoutCount,
        hasFoldOrHinge: hasFoldOrHinge,
      ),
      displayId: view.display.id,
      viewId: view.viewId,
      metricsEpoch: _DeviceDisplayMetricsEpoch.current,
      displayFeaturesKey: displayFeaturesKey.toString(),
      hasSinglePlatformView: view.platformDispatcher.views.length == 1,
    );
  }

  static DeviceDisplayPlatformKind? get _platformKind {
    if (kIsWeb) return null;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => DeviceDisplayPlatformKind.android,
      TargetPlatform.iOS => DeviceDisplayPlatformKind.ios,
      TargetPlatform.fuchsia || TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows => null,
    };
  }

  static bool _isPhone(DeviceDisplayMetrics metrics) {
    final shortSide = metrics.displaySize.shortestSide;
    final longSide = metrics.displaySize.longestSide;
    final aspectRatio = longSide / shortSide;
    return !metrics.hasFoldOrHinge && shortSide >= 240 && shortSide < 600 && aspectRatio >= 4 / 3 && aspectRatio <= 3;
  }

  static Future<DeviceDisplayPlatformCornerRadii?> _androidCornerRadii(
    DeviceDisplayMetrics metrics, {
    required int displayId,
    required int viewId,
    required int metricsEpoch,
    required String displayFeaturesKey,
  }) {
    final key = (
      platform: DeviceDisplayPlatform.instance,
      displayId: displayId,
      viewId: viewId,
      metricsEpoch: metricsEpoch,
      displaySize: metrics.displaySize,
      viewSize: metrics.viewSize,
      devicePixelRatio: metrics.devicePixelRatio,
      viewPadding: metrics.viewPadding,
      systemGestureInsets: metrics.systemGestureInsets,
      displayCutoutBounds: metrics.displayCutoutBounds,
      displayCutoutCount: metrics.displayCutoutCount,
      hasFoldOrHinge: metrics.hasFoldOrHinge,
      displayFeaturesKey: displayFeaturesKey,
    );
    final completed = _completedAndroidRequests[key];
    if (completed != null) {
      return Future<DeviceDisplayPlatformCornerRadii?>.value(completed);
    }
    final pending = _pendingAndroidRequests[key];
    if (pending != null) return pending;

    final request = _performAndCacheAndroidCornerRadiiRequest(
      key,
      metrics: metrics,
    );
    _pendingAndroidRequests[key] = request;
    return request;
  }

  static Future<DeviceDisplayPlatformCornerRadii?> _performAndCacheAndroidCornerRadiiRequest(
    Object key, {
    required DeviceDisplayMetrics metrics,
  }) async {
    try {
      final radii = await _performAndroidCornerRadiiRequest(metrics);
      if (radii == null) return null;
      if (_completedAndroidRequests.length >= _maximumAndroidRequestCacheEntries) {
        _completedAndroidRequests.remove(
          _completedAndroidRequests.keys.first,
        );
      }
      _completedAndroidRequests[key] = radii;
      return radii;
    } finally {
      unawaited(_pendingAndroidRequests.remove(key));
    }
  }

  static Future<DeviceDisplayPlatformCornerRadii?> _performAndroidCornerRadiiRequest(
    DeviceDisplayMetrics metrics,
  ) async {
    final devicePixelRatio = metrics.devicePixelRatio;
    try {
      return await DeviceDisplayPlatform.instance.getCornerRadii(
        displayWidth: metrics.displaySize.width * devicePixelRatio,
        displayHeight: metrics.displaySize.height * devicePixelRatio,
        viewWidth: metrics.viewSize.width * devicePixelRatio,
        viewHeight: metrics.viewSize.height * devicePixelRatio,
        hasSinglePlatformView: true,
      );
    } on Object {
      return null;
    }
  }

  static BorderRadius? _logicalCornerRadii(
    DeviceDisplayPlatformCornerRadii? radii, {
    required DeviceDisplayMetrics metrics,
  }) {
    if (radii == null) return null;

    final physicalLimit = metrics.displaySize.shortestSide * metrics.devicePixelRatio / 2;
    final values = [
      radii.topLeft,
      radii.topRight,
      radii.bottomRight,
      radii.bottomLeft,
    ];
    if (values.any(
      (value) => !value.isFinite || value < 0 || value > physicalLimit,
    )) {
      return null;
    }

    final devicePixelRatio = metrics.devicePixelRatio;
    return BorderRadius.only(
      topLeft: Radius.circular(radii.topLeft / devicePixelRatio),
      topRight: Radius.circular(radii.topRight / devicePixelRatio),
      bottomRight: Radius.circular(radii.bottomRight / devicePixelRatio),
      bottomLeft: Radius.circular(radii.bottomLeft / devicePixelRatio),
    );
  }

  static bool _isUsableSize(Size size) {
    return _isPositiveFinite(size.width) && _isPositiveFinite(size.height);
  }

  static bool _isPositiveFinite(double value) {
    return value.isFinite && value > 0;
  }
}
