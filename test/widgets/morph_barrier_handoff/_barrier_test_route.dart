part of '../morph_barrier_handoff_test.dart';

final class _BarrierTestRoute extends PageRouteBuilder<void> {
  new({required Widget child})
    : super(
        opaque: false,
        barrierColor: Colors.white54,
        transitionDuration: const Duration(seconds: 1),
        reverseTransitionDuration: const Duration(seconds: 1),
        pageBuilder: (context, animation, secondaryAnimation) => child,
      );

  void previewReturn() => controller!.value = .5;

  void cancelReturn() => controller!.forward();
}
