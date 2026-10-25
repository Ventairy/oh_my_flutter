import 'package:flutter/painting.dart';

/// Exercises a shadow whose painted sigma differs from its base radius.
class ContourShadowCustomShadow extends Shadow {
  /// Creates a shadow with an independently overridden blur sigma.
  const new(this._sigma) : super(blurRadius: 4, offset: const Offset(0, 2));

  final double _sigma;

  @override
  double get blurSigma => _sigma;
}
