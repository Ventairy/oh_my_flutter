part of 'contour.dart';

/// Controls isolated mesh support for focused rendering regression tests.
@visibleForTesting
class ContourBoxGaussianShadowTestHarness {
  /// Chooses mesh support without changing production platform capabilities.
  new test({required this._supported});

  final bool _supported;

  static ContourBoxGaussianShadowTestHarness? _installed;

  /// Uses this capability for subsequently mounted Contours in debug tests.
  void install() => _installed = this;

  /// Restores normal construction without changing other installed overrides.
  void dispose() {
    if (identical(_installed, this)) _installed = null;
  }
}
