import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

part 'effects/fade_in_motion_effect.dart';
part 'effects/floating_motion_effect.dart';
part 'effects/move_motion_effect.dart';
part 'effects/scale_in_motion_effect.dart';
part 'internals/motion_animation.dart';
part 'internals/motion_animation_group.dart';
part 'internals/motion_animation_host.dart';
part 'internals/motion_effect_bounds.dart';
part 'internals/motion_effect_validator.dart';
part 'internals/motion_render_effect.dart';
part 'internals/motion_scheduler.dart';
part 'internals/motion_transition.dart';
part 'internals/motion_types.dart';
part 'internals/optimized_text_motion.dart';
part 'internals/render_motion_transition.dart';
part 'internals/render_optimized_text_motion.dart';
part 'internals/text_motion_effect.dart';
part 'internals/text_motion_transition.dart';
part 'motion_effect.dart';
part 'motion_effect_transform.dart';
part 'motion_playback.dart';
part 'text_motion.dart';

/// Applies one or more reusable [MotionEffect]s to [child].
///
/// [Motion] owns the animation lifecycle and applies each effect's shared
/// visual operations to the supplied child. Use [Motion.list] to run multiple
/// effects together. Motion also respects reduced-motion preferences and
/// [TickerMode].
///
/// ```dart
/// Motion(
///   effect: const FloatingMotionEffect(
///     delay: Duration(milliseconds: 300),
///   ),
///   child: const Icon(Icons.cloud),
/// )
/// ```
class Motion extends StatelessWidget {
  /// Creates a widget that applies one [effect] to [child].
  const Motion({
    required this.effect,
    required this.child,
    this.interactive = false,
    super.key,
  }) : effects = null;

  /// Creates a widget that applies [effects] concurrently to [child].
  ///
  /// Each effect has independent delay, duration, curve, and playback values.
  /// The first effect is applied first and each following effect composes
  /// around the result. The list must contain at least one effect and must not
  /// be mutated after being passed to this constructor.
  const Motion.list({
    required this.effects,
    required this.child,
    this.interactive = false,
    super.key,
  }) : effect = null;

  /// Single effect supplied to the default constructor.
  ///
  /// This is null when the widget was created with [Motion.list].
  final MotionEffect? effect;

  /// Effects supplied to the multi-effect constructor.
  ///
  /// This is null when the widget was created with the default constructor.
  final List<MotionEffect>? effects;

  /// Whether [child] accepts pointer interaction during the effect lifecycle.
  ///
  /// This defaults to false, so all pointer interaction is ignored while at
  /// least one effect is waiting or playing. Set this to true to keep the child
  /// interactive throughout the motion lifecycle. Interaction becomes enabled
  /// after every one-shot effect completes. Looping effects keep interaction
  /// disabled for as long as they remain mounted when this is false.
  final bool interactive;

  /// Widget receiving the motion treatment.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final resolvedEffects = effect == null ? List<MotionEffect>.of(effects!) : <MotionEffect>[effect!];
    return _MotionAnimationHost(
      effects: resolvedEffects,
      interactive: interactive,
      transitionBuilder: (applications) => _MotionTransition(
        applications: applications,
        child: child,
      ),
    );
  }
}
