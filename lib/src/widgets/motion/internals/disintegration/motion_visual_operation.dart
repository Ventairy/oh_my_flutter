part of '../../motion.dart';

class _MotionVisualOperation {
  new(this.kind);

  final _MotionVisualOperationKind kind;
  double scale = 1;
  double cosine = 1;
  double sine = 0;
  double x = 0;
  double y = 0;
  double opacity = 1;
  double blurSigma = 0;
  bool callsBlur = false;
  double progress = 0;
  double? loopPhase;
  double directionX = 0;
  double directionY = 0;
  double particleSize = MotionEffectTransform.defaultParticleSize;
}
