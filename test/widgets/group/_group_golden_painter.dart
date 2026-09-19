part of '../group_golden_test.dart';

class _GroupGoldenPainter extends CustomPainter {
  const new(this.snapshot);
  final GroupSnapshot snapshot;
  @override
  void paint(Canvas canvas, Size size) => snapshot.paint(canvas, Offset.zero);
  @override
  bool shouldRepaint(_GroupGoldenPainter oldDelegate) => snapshot != oldDelegate.snapshot;
}
