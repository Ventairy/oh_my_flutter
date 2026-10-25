import 'package:oh_my_flutter/src/widgets/contour/contour_trace_admission.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';

/// Exercises production-sized trace admission without starting a renderer.
class ContourTraceAdmissionTestHarness {
  /// Creates independent work capacity with the production tracing limits.
  new({int maxBytes = 64 * 1024 * 1024}) : budget = ContourWorkBudget.test(maxBytes: maxBytes) {
    admission = ContourTraceAdmission(
      budget: budget,
      maximumPixels: 3 * 1024 * 1024,
      maxGeometryBytes: 4 * 1024 * 1024,
      maxContourPoints: 32768,
    );
  }

  /// The underlying capacity shared by workspace, source, and legacy leases.
  final ContourWorkBudget budget;

  /// The trace manager being exercised.
  late final ContourTraceAdmission admission;

  /// Requests a small source unless explicit capture dimensions are supplied.
  ContourTraceAdmissionRequest request({int width = 20, int height = 20, int legacyBytes = 1024 * 1024}) =>
      admission.request(width: width, height: height, legacyBytes: legacyBytes, owner: Object());
}
