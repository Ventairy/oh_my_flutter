part of 'contour.dart';

class _ContourKnownBoxGeometry {
  const new _(this.roundedRect, this.circle);

  final RRect roundedRect;
  final bool circle;

  // Only positive axis-aligned uniform scaling preserves circular corners and
  // lets expansion remain a single exact filled primitive in capture space.
  static _ContourKnownBoxGeometry? resolve(
    RenderBox source,
    BoxDecoration box,
    TextDirection? textDirection,
    Matrix4 transform,
  ) {
    final t = transform.storage;
    final scale = t[0];
    if (t[1] != 0 || t[4] != 0 || scale <= 0 || scale != t[5]) return null;
    final rect = Offset.zero & source.size;
    final offset = Offset(t[12], t[13]);
    if (box.shape == BoxShape.circle) {
      final center = rect.center * scale + offset;
      return _ContourKnownBoxGeometry._(
        RRect.fromRectAndRadius(
          Rect.fromCircle(center: center, radius: source.size.shortestSide * scale / 2),
          Radius.circular(source.size.shortestSide * scale / 2),
        ),
        true,
      );
    }
    // Normalize against the original bounds before expansion. Clamping after
    // expansion changes the original shape when corner radii overlap.
    final sourceRRect =
        (box.borderRadius?.resolve(textDirection).toRRect(rect) ?? RRect.fromRectAndRadius(rect, Radius.zero))
            .scaleRadii();
    final radii = [sourceRRect.tlRadius, sourceRRect.trRadius, sourceRRect.blRadius, sourceRRect.brRadius];
    if (radii.any((radius) => radius.x != radius.y)) return null;
    final targetRect = Rect.fromLTRB(
      rect.left * scale + offset.dx,
      rect.top * scale + offset.dy,
      rect.right * scale + offset.dx,
      rect.bottom * scale + offset.dy,
    );
    return _ContourKnownBoxGeometry._(
      RRect.fromRectAndCorners(
        targetRect,
        topLeft: sourceRRect.tlRadius * scale,
        topRight: sourceRRect.trRadius * scale,
        bottomLeft: sourceRRect.blRadius * scale,
        bottomRight: sourceRRect.brRadius * scale,
      ),
      false,
    );
  }

  void paint(Canvas canvas, Paint paint, double amount) {
    if (circle) {
      canvas.drawCircle(roundedRect.outerRect.center, roundedRect.width / 2 + amount, paint);
      return;
    }
    final expanded = roundedRect.inflate(amount);
    if (expanded.isRect) {
      canvas.drawRect(expanded.outerRect, paint);
    } else {
      canvas.drawRRect(expanded, paint);
    }
  }
}
