import 'package:flutter/widgets.dart';

import 'contour_colored_box_admission_wide_element.dart';

/// Exposes an unknown element whose public traversal would enumerate many visits.
class ContourColoredBoxAdmissionWideWidget extends StatelessWidget {
  /// Creates an ordinary one-child render tree with observable element traversal.
  const new({required this.onVisit, required this.child, super.key});

  /// Records entry into the unknown element's public child traversal.
  final void Function() onVisit;

  /// The actual mounted child, independent of the traversal stress fixture.
  final Widget child;

  @override
  StatelessElement createElement() => ContourColoredBoxAdmissionWideElement(this);

  @override
  Widget build(BuildContext context) => child;
}
