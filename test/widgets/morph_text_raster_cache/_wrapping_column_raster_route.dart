part of '../morph_text_raster_cache_test.dart';

class _WrappingColumnRasterRoute extends PageRouteBuilder<void> {
  new({required super.pageBuilder})
    : super(
        transitionDuration: const Duration(milliseconds: 400),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        opaque: false,
        transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
      );

  void holdAt(double progress) {
    controller!
      ..stop()
      ..value = progress;
  }
}
