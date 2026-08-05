part of '../motion.dart';

/// Cached paint extents sampled from one motion effect.
class _MotionEffectBounds {
  const _MotionEffectBounds({
    required this.maximumAbsoluteTranslationX,
    required this.maximumAbsoluteTranslationY,
    required this.maximumAbsoluteScale,
  });

  final double maximumAbsoluteTranslationX;

  final double maximumAbsoluteTranslationY;

  final double maximumAbsoluteScale;
}
