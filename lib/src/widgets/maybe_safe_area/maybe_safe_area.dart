import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

part '_maybe_safe_area_bounds.dart';
part '_maybe_safe_area_geometry.dart';
part '_maybe_safe_area_layer.dart';
part '_maybe_safe_area_types.dart';
part '_render_maybe_safe_area.dart';
part 'maybe_safe_area_behavior.dart';

/// Keeps a compact [child] away from device cutouts and system UI, but only
/// when the child reaches an unsafe edge.
///
/// Use this around floating controls, overlays, or scrolling widgets that can
/// move near the edge of the screen. A child that is already clear of the
/// enabled edges stays exactly where it was placed. If it overlaps one, it
/// moves only far enough to become visible and usable again.
///
/// The avoided position is visible immediately. By default, avoidance stays
/// current as the child scrolls or transforms. Set [behavior] to
/// [MaybeSafeAreaBehavior.preserve] when the initial correction should instead
/// move with an enclosing surface. Surrounding layout and scroll extent do not
/// change. Use [SafeArea] when content should reflow or reserve space around
/// unsafe areas.
///
/// See the [MaybeSafeArea guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/maybe_safe_area.md)
/// for positioning examples, edge configuration, and layout constraints.
class MaybeSafeArea extends SingleChildRenderObjectWidget {
  /// Creates a widget that conditionally avoids unsafe view edges.
  ///
  /// The [behavior] controls whether avoidance follows later movement or is
  /// preserved relative to the moving child. Each enabled edge participates
  /// independently.
  const MaybeSafeArea({
    required super.child,
    this.behavior = MaybeSafeAreaBehavior.live,
    this.left = true,
    this.top = true,
    this.right = true,
    this.bottom = true,
    super.key,
  });

  /// How avoidance responds after the child's first rendered position.
  ///
  /// The default keeps avoidance current as the child moves. Use
  /// [MaybeSafeAreaBehavior.preserve] when an enclosing surface should carry
  /// the initially avoided child without changing its position within that
  /// surface.
  final MaybeSafeAreaBehavior behavior;

  /// Whether [child] should avoid the left unsafe edge when it reaches it.
  final bool left;

  /// Whether [child] should avoid the top unsafe edge when it reaches it.
  final bool top;

  /// Whether [child] should avoid the right unsafe edge when it reaches it.
  final bool right;

  /// Whether [child] should avoid the bottom unsafe edge when it reaches it.
  final bool bottom;

  @override
  RenderObject createRenderObject(BuildContext context) {
    assert(
      debugCheckHasMediaQuery(context),
      'MaybeSafeArea requires an ancestor MediaQuery.',
    );
    return _RenderMaybeSafeArea(
      initialBehavior: behavior,
      initialDevicePixelRatio: _devicePixelRatioOf(context),
      initialEnabledEdges: (left: left, top: top, right: right, bottom: bottom),
      initialViewPadding: MediaQuery.paddingOf(context),
      initialViewSize: MediaQuery.sizeOf(context),
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderMaybeSafeArea)
      ..behavior = behavior
      ..devicePixelRatio = _devicePixelRatioOf(context)
      ..enabledEdges = (left: left, top: top, right: right, bottom: bottom)
      ..viewPadding = MediaQuery.paddingOf(context)
      ..viewSize = MediaQuery.sizeOf(context);
  }

  double _devicePixelRatioOf(BuildContext context) {
    final mediaQueryDevicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final viewDevicePixelRatio = View.of(context).devicePixelRatio;
    return mediaQueryDevicePixelRatio == viewDevicePixelRatio ? mediaQueryDevicePixelRatio : viewDevicePixelRatio;
  }
}
