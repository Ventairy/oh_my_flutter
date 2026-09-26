part of 'skeleton_crossfade_benchmark.dart';

class _CrossfadePaintProbePainter extends CustomPainter {
  const new();

  static int paintCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paintCount += 1;
    canvas.drawCircle(size.center(Offset.zero), math.min(size.width, size.height) / 2, Paint()..color = Colors.blue);
  }

  @override
  bool shouldRepaint(_CrossfadePaintProbePainter oldDelegate) => false;
}
