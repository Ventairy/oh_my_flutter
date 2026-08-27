part of 'skeleton_benchmark.dart';

class _PaintProbePainter extends CustomPainter {
  const _PaintProbePainter();

  static int paintCount = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paintCount += 1;
    canvas.drawCircle(
      size.center(Offset.zero),
      math.min(size.width, size.height) / 2,
      Paint()..color = Colors.blue,
    );
  }

  @override
  bool shouldRepaint(_PaintProbePainter oldDelegate) => false;
}
