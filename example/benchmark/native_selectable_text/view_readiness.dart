import 'package:flutter/widgets.dart';

/// Describes whether a benchmark view can produce attributable frame timings.
final class NativeSelectableTextBenchmarkViewReadiness {
  /// Creates one immutable observation of lifecycle and display state.
  const NativeSelectableTextBenchmarkViewReadiness({
    required this.lifecycleState,
    required this.logicalSize,
    required this.physicalSize,
    required this.devicePixelRatio,
    required this.refreshRate,
  });

  /// Lifecycle state observed with the view metrics.
  final AppLifecycleState? lifecycleState;

  /// Logical dimensions observed for the Flutter view.
  final Size logicalSize;

  /// Physical pixel dimensions observed for the Flutter view.
  final Size physicalSize;

  /// Physical pixels represented by one logical pixel.
  final double devicePixelRatio;

  /// Display refresh rate used to derive the frame budget.
  final double refreshRate;

  /// Whether lifecycle and every view metric are valid for measurement.
  bool get isReady {
    return lifecycleState == AppLifecycleState.resumed &&
        _sizeIsFiniteAndPositive(logicalSize) &&
        _sizeIsFiniteAndPositive(physicalSize) &&
        _isFiniteAndPositive(devicePixelRatio) &&
        _isFiniteAndPositive(refreshRate);
  }

  /// Human-readable values included when startup readiness times out.
  String get diagnostic {
    return 'lifecycle=${lifecycleState?.name ?? 'null'}; '
        'logical_size=${logicalSize.width}x${logicalSize.height}; '
        'physical_size=${physicalSize.width}x${physicalSize.height}; '
        'device_pixel_ratio=$devicePixelRatio; '
        'refresh_rate_hz=$refreshRate';
  }

  static bool _sizeIsFiniteAndPositive(Size size) {
    final widthIsValid = _isFiniteAndPositive(size.width);
    final heightIsValid = _isFiniteAndPositive(size.height);
    return widthIsValid && heightIsValid;
  }

  static bool _isFiniteAndPositive(double value) {
    return value.isFinite && value > 0;
  }
}
