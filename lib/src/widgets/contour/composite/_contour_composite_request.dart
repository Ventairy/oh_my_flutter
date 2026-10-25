part of 'contour_composite_source_io.dart';

class _ContourCompositeRequest {
  new({
    required this.picture,
    required this.width,
    required this.height,
    required this.sourceRatio,
    required this.outputRatio,
    required this.amount,
    required this.color,
    required this.shadow,
    required this.sigma,
    required this.dx,
    required this.dy,
    required this.onFinished,
  });
  ui.Picture? picture;
  final int width;
  final int height;
  final double sourceRatio;
  final double outputRatio;
  final double amount;
  final int color;
  final int shadow;
  final double sigma;
  final double dx;
  final double dy;
  final void Function() onFinished;
  final result = Completer<ContourCompositeResult?>();
  void Function()? onCancelled;
  bool cancelled = false;

  void cancel() {
    if (cancelled) return;
    cancelled = true;
    finish(null);
    onCancelled?.call();
  }

  void finish(ContourCompositeResult? value) {
    if (result.isCompleted) {
      value?.dispose();
      return;
    }
    result.complete(value);
    picture?.dispose();
    picture = null;
    onFinished();
  }
}
