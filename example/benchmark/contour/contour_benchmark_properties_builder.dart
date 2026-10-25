import 'package:flutter/foundation.dart';

/// Retains optional benchmark diagnostics when profile assertions are disabled.
class ContourBenchmarkPropertiesBuilder extends DiagnosticPropertiesBuilder {
  @override
  void add(DiagnosticsNode property) {
    // Flutter's default builder appends only inside assert. The benchmark must
    // retain these fields in profile without changing Contour's public API.
    properties.add(property);
  }
}
