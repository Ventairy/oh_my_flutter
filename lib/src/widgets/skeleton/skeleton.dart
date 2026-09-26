library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' hide Image;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

part '_skeleton_animation_clock.dart';
part '_skeleton_bone_command.dart';
part '_skeleton_bone_commands.dart';
part '_skeleton_bone_segment.dart';
part '_skeleton_bone_segment_mode.dart';
part '_skeleton_bone_shape.dart';
part '_skeleton_built_in_paint_key.dart';
part '_skeleton_canvas.dart';
part '_skeleton_clip_path_command.dart';
part '_skeleton_clip_rect_command.dart';
part '_skeleton_clip_rrect_command.dart';
part '_skeleton_clip_rsuperellipse_command.dart';
part '_skeleton_crossfade_transition.dart';
part '_skeleton_custom_transition.dart';
part '_skeleton_defer_to_children_behavior.dart';
part '_skeleton_descendant_render_object.dart';
part '_skeleton_descendant_render_object_widget.dart';
part '_skeleton_draw_circle_command.dart';
part '_skeleton_draw_drrect_command.dart';
part '_skeleton_draw_oval_command.dart';
part '_skeleton_draw_path_command.dart';
part '_skeleton_draw_rrect_command.dart';
part '_skeleton_effect_frame_cache.dart';
part '_skeleton_hide_behavior.dart';
part '_skeleton_paint_scope.dart';
part '_skeleton_paint_as_bone_behavior.dart';
part '_skeleton_paint_state.dart';
part '_skeleton_painting_context.dart';
part '_skeleton_render_object.dart';
part '_skeleton_render_object_widget.dart';
part '_skeleton_restore_command.dart';
part '_skeleton_restore_to_count_command.dart';
part '_skeleton_rotate_command.dart';
part '_skeleton_save_command.dart';
part '_skeleton_scale_command.dart';
part '_skeleton_scope.dart';
part '_skeleton_skew_command.dart';
part '_skeleton_transform_command.dart';
part '_skeleton_transition_host.dart';
part '_skeleton_translate_command.dart';
part 'skeleton_animated_effect_base.dart';
part 'skeleton_effect.dart';
part 'skeleton_descendant.dart';
part 'skeleton_descendant_behavior.dart';
part 'skeleton_fade_effect.dart';
part 'skeleton_shimmer_effect.dart';
part 'skeleton_static_effect_base.dart';
part 'skeleton_style.dart';
part 'skeleton_transition.dart';

/// A loading placeholder that replaces a widget subtree's painted content with skeleton bones.
///
/// The child keeps its original layout. On each branch, the first descendant
/// that paints visible content becomes a neutral placeholder shape and its
/// children are omitted. Use [SkeletonDescendant] to customize individual
/// branches. Set [enabled] to `false` to render [child] normally.
///
/// Animated effects stop when the platform requests reduced motion, leaving a
/// visible static placeholder in place.
/// Set [transition] to animate switches between the placeholder and content.
///
/// See the [Skeleton guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/skeleton.md)
/// for configuration examples and usage guidance.
class Skeleton extends StatelessWidget {
  /// Creates a loading skeleton around [child].
  const new({
    required this.child,
    super.key,
    this.enabled = true,
    this.semanticsLabel,
    this.style = const SkeletonStyle(),
    this.transition,
  });

  /// The widget subtree represented by the skeleton.
  final Widget child;

  /// Whether the child is currently shown as a skeleton.
  final bool enabled;

  /// A localized accessibility label for the loading region.
  ///
  /// While the skeleton is enabled, this label replaces the hidden child's
  /// semantics and is exposed as a live loading status. If omitted, provide an
  /// equivalent loading status outside the skeleton.
  final String? semanticsLabel;

  /// The colors, geometry, and optional paint effect used by the skeleton.
  final SkeletonStyle style;

  /// An optional transition when [enabled] changes.
  ///
  /// Without a transition, the appearance changes immediately.
  final SkeletonTransition? transition;

  @override
  Widget build(BuildContext context) =>
      transition == null ? _buildAppearance(context, child: child) : _SkeletonTransitionHost(skeleton: this);

  Widget _buildAppearance(BuildContext context, {required Widget child, Animation<double>? blend}) {
    final effect = style.effect;
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final tickerMode = TickerMode.valuesOf(context);
    final animate =
        enabled &&
        effect is SkeletonAnimatedEffectBase &&
        effect.duration > Duration.zero &&
        !disableAnimations &&
        tickerMode.enabled;
    final effectiveStyle = effect is SkeletonAnimatedEffectBase && disableAnimations
        ? SkeletonStyle(color: style.color, shape: style.shape)
        : style;

    final skeleton = ExcludeFocus(
      excluding: enabled,
      child: ExcludeSemantics(
        excluding: enabled,
        child: IgnorePointer(
          ignoring: enabled,
          child: TickerMode(
            enabled: tickerMode.enabled && !enabled,
            forceFrames: tickerMode.forceFrames,
            child: _SkeletonRenderObjectWidget(
              enabled: enabled,
              animate: animate,
              forceFrames: tickerMode.forceFrames,
              style: effectiveStyle,
              blend: blend,
              child: child,
            ),
          ),
        ),
      ),
    );

    final scopedSkeleton = _SkeletonScope(
      enabled: enabled,
      child: skeleton,
    );

    if (!enabled || semanticsLabel == null) return scopedSkeleton;
    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticsLabel,
      role: SemanticsRole.loadingSpinner,
      child: scopedSkeleton,
    );
  }
}
