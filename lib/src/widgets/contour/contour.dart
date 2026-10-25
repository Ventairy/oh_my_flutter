import 'dart:async';
import 'dart:collection';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show MaterialAccentColor, MaterialColor;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../rendering/resting_paint_transform.dart';
import 'capture/contour_layer_picture_snapshot.dart';
import 'capture/contour_layer_snapshot_content.dart';
import 'composite/contour_composite_result.dart';
import 'composite/contour_composite_source.dart';
import 'contour_initial_frame_fence.dart';
import 'contour_native_mask_picture_cache.dart';
import 'contour_native_proof_queue.dart';
import 'contour_shadow_atlas_rasterizer.dart';
import 'contour_trace_admission.dart';
import 'contour_work_budget.dart';
import 'geometry/contour_geometry_cache.dart';
import 'tracing/contour_native_port_session.dart';
import 'tracing/contour_native_trace_policy.dart';

part 'contour_controller.dart';
part 'contour_presentation_test_harness.dart';
part '_contour_capture.dart';
part '_contour_composite_backing.dart';
part '_contour_composite_pending_group.dart';
part '_contour_colored_box_source.dart';
part '_contour_curve_simplifier.dart';
part '_contour_declared_source.dart';
part '_contour_known_box_source.dart';
part '_contour_known_box_geometry.dart';
part '_contour_box_gaussian_mesh.dart';
part '_contour_box_gaussian_mesh_cache.dart';
part '_contour_box_gaussian_shadow.dart';
part '_contour_box_gaussian_shadow_test_harness.dart';
part '_contour_decoration_layer.dart';
part '_contour_layer.dart';
part '_contour_view_metrics_observer.dart';
part '_contour_native_text.dart';
part '_contour_native_text_span.dart';
part '_contour_native_text_cache.dart';
part '_contour_native_text_cache_entry.dart';
part '_contour_native_text_cache_key.dart';
part '_contour_native_verification.dart';
part '_contour_picture_decoration_layer.dart';
part '_contour_processor.dart';
part '_contour_worker_lifecycle.dart';
part '_contour_processor_test_harness.dart';
part '_contour_render_widget.dart';
part '_contour_shadow_cache.dart';
part '_contour_shadow_atlas.dart';
part '_contour_shadow_atlas_key.dart';
part '_contour_shadow_atlas_source.dart';
part '_contour_atlas_queue.dart';
part '_contour_image_pool.dart';
part '_contour_image_resource.dart';
part '_contour_shadow_image_key.dart';
part '_contour_source_preflight.dart';
part '_render_contour.dart';
part '_render_contour_capture.dart';
part '_contour_tracer.dart';
part '_contour_trace_result.dart';
part '_contour_web_work.dart';

/// Draws a colored contour around the visible edges of a child.
///
/// Use it to give text a contrasting border or lift icon artwork off its
/// background. The contour follows both outer and inner edges. Enclosed spaces
/// shrink as [amount] grows and close when the expanded edges meet.
///
/// The child keeps its layout, interaction, and semantics. Amount and shadows
/// can extend beyond its layout bounds, where ancestors may clip them. Add
/// padding outside this widget when that space should be reserved.
///
/// The child and its initial backing appear together after asynchronous
/// preparation, with layout space reserved until then. Interaction and
/// semantics become available when the content appears. Later changes keep the
/// live child visible while its backing updates; an outdated backing is hidden.
/// Continuously changing artwork may have periods without a backing.
///
/// See the [Contour guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/contour.md).
class Contour extends StatelessWidget {
  /// Creates a contour for [child] using [color].
  const new({
    required this.color,
    required this.child,
    this.amount = 0,
    this.shadows = const [],
    this.controller,
    this.prepareWhenHidden = false,
    super.key,
  }) : assert(
         amount >= 0 && amount < double.infinity,
         'Amount must be finite and nonnegative.',
       );

  /// The color drawn behind the child and around its visible edges.
  ///
  /// The color's opacity determines the backing's opacity independently of the
  /// child's opacity. Transparent areas remain open unless [amount] closes them.
  final Color color;

  /// How far to expand the backing in logical pixels without scaling the child.
  ///
  /// The contour uses rounded joins, keeping curves smooth and rounding off
  /// corners without pointed protrusions. Must be finite and nonnegative.
  final double amount;

  /// Shadows painted behind the expanded backing, in list order.
  ///
  /// Each shadow follows the backing's shape. Blur radii must be finite and
  /// nonnegative, and offsets must be finite. Do not mutate this list while the
  /// widget is mounted.
  final List<Shadow> shadows;

  /// Observes when the current artwork can be revealed with its backing.
  ///
  /// Use its readiness to start an entrance animation. A controller can be
  /// attached to one Contour at a time. Readiness also settles when unsupported
  /// artwork must be shown without a backing.
  final ContourController? controller;

  /// Prepares laid-out artwork even while an ancestor hides it from painting.
  ///
  /// Enable this for a held entrance animation or an offstage upcoming screen.
  /// Keep the same mounted widget and layout when revealing it. This performs
  /// work while hidden; enable it only for content likely to be shown soon.
  /// Preparation does not guarantee that its first visible frame has already
  /// been rendered by the GPU.
  final bool prepareWhenHidden;

  /// The content to display above its backing.
  ///
  /// Supports Flutter-painted text, icons, images, and compositions. An opaque
  /// background becomes part of the shape. Platform views and other content
  /// that cannot be captured as an image are not supported.
  ///
  /// Small details in unusually large artwork may be simplified. Extremely
  /// detailed artwork may appear without a backing; simplify it or contour
  /// smaller pieces separately.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    assert(
      _debugValidateShadows(),
      'Shadows must have finite offsets and nonnegative finite blur radii.',
    );
    return _ContourRenderWidget(
      color: color,
      controller: controller,
      prepareWhenHidden: prepareWhenHidden,
      source: child,
      amount: amount,
      shadows: shadows,
      deferPrewarm: _ContourDeclaredSource.canDeferPrewarm(child),
      pixelRatio: MediaQuery.maybeDevicePixelRatioOf(context) ?? View.of(context).devicePixelRatio,
      child: _ContourCapture(child: child),
    );
  }

  bool _debugValidateShadows() {
    for (final shadow in shadows) {
      assert(
        shadow.blurRadius.isFinite && shadow.blurRadius >= 0,
        'Shadow blur must be finite and nonnegative.',
      );
      assert(
        shadow.offset.dx.isFinite && shadow.offset.dy.isFinite,
        'Shadow offsets must be finite.',
      );
    }
    return true;
  }
}
