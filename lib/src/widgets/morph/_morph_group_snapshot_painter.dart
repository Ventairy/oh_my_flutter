part of 'morph.dart';

final class _MorphGroupSnapshotPainter extends CustomPainter {
  new(this.capture) : super(repaint: capture);
  final _MorphGroupCapture capture;

  @override
  void paint(Canvas canvas, Size size) => capture.snapshot.paint(canvas, Offset.zero);

  @override
  bool shouldRepaint(_MorphGroupSnapshotPainter oldDelegate) => !identical(capture, oldDelegate.capture);
}
