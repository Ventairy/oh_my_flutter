part of '../../motion.dart';

abstract final class _MotionDisintegrationParameters {
  static const maximumParticleCount = 18000;
  static const seed = 42;
  static const columnDelay = 0.16;
  static const randomDelay = 0.04;
  static const lifetimeBase = 0.55;
  static const lifetimeRange = 0.45;
  static const horizontalDriftBase = 0.02;
  static const horizontalDriftRange = 0.08;
  static const verticalDriftBase = 0.015;
  static const verticalDriftRange = 0.075;
  static const curlBase = 0.003;
  static const curlRange = 0.01;
  static const breakupRate = 5.0;
  static const breakupShrink = 0.4;
  static const lifetimeShrink = 0.7;
  static const curlRotation = 3.0;
  static const fadeStart = 0.1;

  static final Float64List geometryParameters = Float64List.fromList([
    columnDelay,
    randomDelay,
    lifetimeBase,
    lifetimeRange,
    horizontalDriftBase,
    horizontalDriftRange,
    verticalDriftBase,
    verticalDriftRange,
    curlBase,
    curlRange,
  ]).asUnmodifiableView();
}
