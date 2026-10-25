import 'package:flutter/widgets.dart';

import 'contour_non_rasterizable_test_render.dart';

/// Provides an unsupported-capture child without creating a platform view.
class ContourNonRasterizableTestSource extends LeafRenderObjectWidget {
  /// Creates the fixed visible source.
  const new({super.key});

  @override
  RenderBox createRenderObject(BuildContext context) => ContourNonRasterizableTestRender();
}
