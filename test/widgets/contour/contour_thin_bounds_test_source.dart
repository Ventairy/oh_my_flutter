import 'package:flutter/widgets.dart';

import 'contour_thin_bounds_test_render.dart';

/// Supplies a visible source whose declared capture exceeds temporary capacity.
class ContourThinBoundsTestSource extends LeafRenderObjectWidget {
  /// Creates the fixed-size visible source.
  const new({super.key});

  @override
  RenderBox createRenderObject(BuildContext context) => ContourThinBoundsTestRender();
}
