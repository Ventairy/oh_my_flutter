import 'package:flutter/widgets.dart';

import 'contour_painted_overflow_test_render_box.dart';

/// Creates a renderer that must remain outside the supplied-source whitelist.
class ContourPaintedOverflowTestWidget extends SingleChildRenderObjectWidget {
  /// Creates an overflow wrapper with additional painted artwork.
  const new({super.key, super.child});

  @override
  ContourPaintedOverflowTestRenderBox createRenderObject(BuildContext context) => ContourPaintedOverflowTestRenderBox();
}
