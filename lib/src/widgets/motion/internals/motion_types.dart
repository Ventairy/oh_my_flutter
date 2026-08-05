part of '../motion.dart';

typedef _MotionApplication = ({
  Animation<double> animation,
  MotionEffect effect,
});

typedef _TextMotionApplication = ({
  Animation<double> animation,
  MotionEffect effect,
  Duration stagger,
  Duration timelineDuration,
});

typedef _TextMotionSprite = ({
  double anchorX,
  double anchorY,
  double bottom,
  double left,
  double right,
  double top,
});
