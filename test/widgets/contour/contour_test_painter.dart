import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Draws geometric fixtures without depending on platform font rendering.
class ContourTestPainter extends CustomPainter {
  /// Creates a fixture with optional repaint-only changes.
  const new({
    this.open = false,
    this.circle = false,
    this.pointed = false,
    this.fringe = false,
    this.fringeWidth = 1 / 3,
    this.specks = false,
    this.dotGrid = false,
    this.strokeWidth = 0,
    this.empty = false,
    this.offset = Offset.zero,
    this.isOpen,
  }) : super(repaint: isOpen);

  /// Whether the counter connects to the outside.
  final bool open;

  /// Whether the fixture has curved exterior edges.
  final bool circle;

  /// Whether the fixture has an acute exterior tip.
  final bool pointed;

  /// Whether the fixture includes a faint connected raster fringe.
  final bool fringe;

  /// The thickness of the connected faint fringe.
  final double fringeWidth;

  /// Whether the fixture includes faint fragments around the main artwork.
  final bool specks;

  /// Whether the artwork is a grid of 256 disconnected opaque one-pixel squares.
  final bool dotGrid;

  /// The width of a native white reference stroke.
  final double strokeWidth;

  /// Whether the fixture paints no pixels.
  final bool empty;

  /// Translation within the fixture.
  final Offset offset;

  /// A paint-only change to the shape.
  final ValueListenable<bool>? isOpen;

  @override
  void paint(Canvas canvas, Size size) {
    if (empty) return;
    if (dotGrid) {
      final paint = Paint()..color = const Color(0xFFFF0000);
      for (var row = 0; row < 16; row++) {
        for (var column = 0; column < 16; column++) {
          canvas.drawRect(Rect.fromLTWH(1 + column * 4.0, 1 + row * 4.0, 1, 1), paint);
        }
      }
      return;
    }
    if (specks) {
      for (final origin in [const Offset(2, 2), Offset(size.width - 3, size.height - 3)]) {
        canvas.drawRect(origin & const Size.square(2 / 3), Paint()..color = const Color(0x28FF0000));
      }
      canvas.drawCircle(size.center(Offset.zero), 12, Paint()..color = const Color(0xFFFF0000));
      return;
    }
    if (fringe) {
      canvas
        ..drawRect(
          Rect.fromLTWH(size.width / 2, size.height / 2 - 16, fringeWidth, 5),
          Paint()..color = const Color(0x01FF0000),
        )
        ..drawCircle(size.center(Offset.zero), 12, Paint()..color = const Color(0xFFFF0000));
      return;
    }
    final path = Path()..fillType = PathFillType.evenOdd;
    if (pointed) {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
    } else if (circle) {
      path.addOval(Offset.zero & size);
    } else {
      path.addRect(Offset.zero & size);
    }
    path.addRect(
      Rect.fromLTWH(
        size.width / 4,
        size.height / 4,
        (isOpen?.value ?? open) ? size.width : size.width / 2,
        size.height / 2,
      ),
    );
    if (strokeWidth > 0) {
      canvas.drawPath(
        path.shift(offset),
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = strokeWidth,
      );
    }
    canvas.drawPath(path.shift(offset), Paint()..color = const Color(0xFFFF0000));
  }

  @override
  bool shouldRepaint(ContourTestPainter oldDelegate) =>
      oldDelegate.open != open ||
      oldDelegate.circle != circle ||
      oldDelegate.pointed != pointed ||
      oldDelegate.fringe != fringe ||
      oldDelegate.fringeWidth != fringeWidth ||
      oldDelegate.specks != specks ||
      oldDelegate.dotGrid != dotGrid ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.empty != empty ||
      oldDelegate.offset != offset ||
      oldDelegate.isOpen != isOpen;
}
