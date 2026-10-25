import 'package:flutter/widgets.dart';

import 'contour_colored_box_admission_wide_widget.dart';

/// Makes an unknown element expensive only if the admission lookup traverses it.
class ContourColoredBoxAdmissionWideElement extends StatelessElement {
  /// Creates the custom element for its otherwise ordinary widget.
  new(ContourColoredBoxAdmissionWideWidget super.widget);

  @override
  void visitChildElements(ElementVisitor visitor) {
    (widget as ContourColoredBoxAdmissionWideWidget).onVisit();
    for (var index = 0; index < 1024; index++) {
      super.visitChildElements(visitor);
    }
  }
}
