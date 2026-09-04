import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../extensions/double_extension.dart';
import 'device_display_platform.dart';
import 'device_display_platform_corner_radii.dart';

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

  static const _maximumRequestCacheEntries = 8;
  static final Map<Object, Future<DeviceDisplayPlatformCornerRadii?>> _pendingRequests = {};
  static final Map<Object, DeviceDisplayPlatformCornerRadii> _completedRequests = {};

  /// Returns the current display corner radii in logical pixels.
  ///
  /// Flutter-provided values take priority, including [BorderRadius.zero].
  /// When Flutter has no value, supported mobile platforms are queried for
  /// trustworthy display information. This method returns null when no such
  /// information is available.
  Future<BorderRadius?> cornerRadii(BuildContext context) {
    final view = View.maybeOf(context);
    final exact = MediaQuery.maybeDisplayCornerRadiiOf(context) ?? _exactCornerRadiiFromView(view);
    if (exact != null) return Future<BorderRadius?>.value(exact);

    final snapshot = _captureSnapshot(view);
    if (snapshot == null) return Future<BorderRadius?>.value();

    return _platformCornerRadii(snapshot);
  }

  static BorderRadius? _exactCornerRadiiFromView(ui.FlutterView? view) {
    if (view == null) return null;

    final radii = view.displayCornerRadii;
    final devicePixelRatio = view.devicePixelRatio;
    if (radii == null || !devicePixelRatio.isPositiveFinite) return null;

    return BorderRadius.only(
      topLeft: Radius.circular(radii.topLeft / devicePixelRatio),
      topRight: Radius.circular(radii.topRight / devicePixelRatio),
      bottomRight: Radius.circular(radii.bottomRight / devicePixelRatio),
      bottomLeft: Radius.circular(radii.bottomLeft / devicePixelRatio),
    );
  }

  static ({
    TargetPlatform platform,
    Size displayPhysicalSize,
    Size viewPhysicalSize,
    double devicePixelRatio,
    int displayId,
    int viewId,
    int metricsEpoch,
    bool hasSinglePlatformView,
  })?
  _captureSnapshot(ui.FlutterView? view) {
    final platform = defaultTargetPlatform;
    if (view == null || !_supportsPlatformCornerRadii(platform)) return null;

    final devicePixelRatio = view.devicePixelRatio;
    final displayPhysicalSize = view.display.size;
    final viewPhysicalSize = view.physicalSize;
    if (!devicePixelRatio.isPositiveFinite ||
        !displayPhysicalSize.width.isPositiveFinite ||
        !displayPhysicalSize.height.isPositiveFinite ||
        !viewPhysicalSize.width.isPositiveFinite ||
        !viewPhysicalSize.height.isPositiveFinite) {
      return null;
    }

    return (
      platform: platform,
      displayPhysicalSize: displayPhysicalSize,
      viewPhysicalSize: viewPhysicalSize,
      devicePixelRatio: devicePixelRatio,
      displayId: view.display.id,
      viewId: view.viewId,
      metricsEpoch: _DeviceDisplayMetricsEpoch.current,
      hasSinglePlatformView: view.platformDispatcher.views.length == 1,
    );
  }

  static bool _supportsPlatformCornerRadii(TargetPlatform platform) {
    if (kIsWeb) return false;

    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  static Future<BorderRadius?> _platformCornerRadii(
    ({
      TargetPlatform platform,
      Size displayPhysicalSize,
      Size viewPhysicalSize,
      double devicePixelRatio,
      int displayId,
      int viewId,
      int metricsEpoch,
      bool hasSinglePlatformView,
    })
    snapshot,
  ) async {
    final platformImplementation = DeviceDisplayPlatform.instance;
    final key = (
      implementation: platformImplementation,
      platform: snapshot.platform,
      displayId: snapshot.displayId,
      viewId: snapshot.viewId,
      metricsEpoch: snapshot.metricsEpoch,
      displayPhysicalSize: snapshot.displayPhysicalSize,
      viewPhysicalSize: snapshot.viewPhysicalSize,
      devicePixelRatio: snapshot.devicePixelRatio,
      hasSinglePlatformView: snapshot.hasSinglePlatformView,
    );
    final completed = _completedRequests[key];
    if (completed != null) {
      return _logicalCornerRadii(
        completed,
        displayPhysicalSize: snapshot.displayPhysicalSize,
        devicePixelRatio: snapshot.devicePixelRatio,
      );
    }

    final pending = _pendingRequests[key];
    final physicalRadii =
        pending ??
        _startPlatformRequest(
          key,
          platformImplementation: platformImplementation,
          displayPhysicalSize: snapshot.displayPhysicalSize,
          viewPhysicalSize: snapshot.viewPhysicalSize,
          hasSinglePlatformView: snapshot.hasSinglePlatformView,
        );
    return _logicalCornerRadii(
      await physicalRadii,
      displayPhysicalSize: snapshot.displayPhysicalSize,
      devicePixelRatio: snapshot.devicePixelRatio,
    );
  }

  static Future<DeviceDisplayPlatformCornerRadii?> _startPlatformRequest(
    Object key, {
    required DeviceDisplayPlatform platformImplementation,
    required Size displayPhysicalSize,
    required Size viewPhysicalSize,
    required bool hasSinglePlatformView,
  }) {
    final request = _performAndCachePlatformRequest(
      key,
      platformImplementation: platformImplementation,
      displayPhysicalSize: displayPhysicalSize,
      viewPhysicalSize: viewPhysicalSize,
      hasSinglePlatformView: hasSinglePlatformView,
    );
    _pendingRequests[key] = request;
    return request;
  }

  static Future<DeviceDisplayPlatformCornerRadii?> _performAndCachePlatformRequest(
    Object key, {
    required DeviceDisplayPlatform platformImplementation,
    required Size displayPhysicalSize,
    required Size viewPhysicalSize,
    required bool hasSinglePlatformView,
  }) async {
    try {
      final radii = await platformImplementation.getCornerRadii(
        displayWidth: displayPhysicalSize.width,
        displayHeight: displayPhysicalSize.height,
        viewWidth: viewPhysicalSize.width,
        viewHeight: viewPhysicalSize.height,
        hasSinglePlatformView: hasSinglePlatformView,
      );
      if (radii == null || !_isValidPlatformRadii(radii, displayPhysicalSize)) {
        return null;
      }
      if (_completedRequests.length >= _maximumRequestCacheEntries) {
        _completedRequests.remove(_completedRequests.keys.first);
      }
      _completedRequests[key] = radii;
      return radii;
    } on Object {
      return null;
    } finally {
      unawaited(_pendingRequests.remove(key));
    }
  }

  static BorderRadius? _logicalCornerRadii(
    DeviceDisplayPlatformCornerRadii? radii, {
    required Size displayPhysicalSize,
    required double devicePixelRatio,
  }) {
    if (radii == null || !_isValidPlatformRadii(radii, displayPhysicalSize)) {
      return null;
    }

    return BorderRadius.only(
      topLeft: Radius.circular(radii.topLeft / devicePixelRatio),
      topRight: Radius.circular(radii.topRight / devicePixelRatio),
      bottomRight: Radius.circular(radii.bottomRight / devicePixelRatio),
      bottomLeft: Radius.circular(radii.bottomLeft / devicePixelRatio),
    );
  }

  static bool _isValidPlatformRadii(
    DeviceDisplayPlatformCornerRadii radii,
    Size displayPhysicalSize,
  ) {
    final physicalLimit = displayPhysicalSize.shortestSide / 2;
    final values = [
      radii.topLeft,
      radii.topRight,
      radii.bottomRight,
      radii.bottomLeft,
    ];
    return values.every(
      (value) => value.isFinite && value >= 0 && value <= physicalLimit,
    );
  }
}
