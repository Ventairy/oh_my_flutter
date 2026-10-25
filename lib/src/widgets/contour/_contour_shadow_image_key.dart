part of 'contour.dart';

@immutable
class _ContourShadowImageKey {
  new({
    required this.maskIdentity,
    required this.amount,
    required this.nativeMask,
    required List<Shadow> shadows,
    required Rect bounds,
    required this.pixelRatio,
  }) : shadows = _snapshot(shadows),
       bounds = Rect.fromLTRB(bounds.left, bounds.top, bounds.right, bounds.bottom);

  final Object maskIdentity;
  final double amount;
  final bool nativeMask;
  final List<Object>? shadows;
  final Rect bounds;
  final double pixelRatio;

  static List<Object>? _snapshot(List<Shadow> shadows) {
    final values = <Object>[];
    for (final shadow in shadows) {
      // Custom paint objects can retain caller state or override their fields.
      // Keep their images per owner instead of trusting value equality.
      if (!const <Type>{Shadow, BoxShadow}.contains(shadow.runtimeType)) return null;
      final color = shadow.color;
      if (!const <Type>{Color, ColorSwatch<int>, MaterialColor, MaterialAccentColor}.contains(color.runtimeType)) {
        return null;
      }
      final offset = shadow.offset;
      if (offset.runtimeType != Offset) return null;
      values.add((shadow.blurSigma, offset.dx, offset.dy, color.a, color.r, color.g, color.b, color.colorSpace));
    }
    return List.unmodifiable(values);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      shadows != null &&
          other is _ContourShadowImageKey &&
          other.shadows != null &&
          identical(maskIdentity, other.maskIdentity) &&
          amount == other.amount &&
          nativeMask == other.nativeMask &&
          listEquals(shadows, other.shadows) &&
          bounds == other.bounds &&
          pixelRatio == other.pixelRatio;

  @override
  int get hashCode => shadows == null
      ? identityHashCode(this)
      : Object.hash(identityHashCode(maskIdentity), amount, nativeMask, Object.hashAll(shadows!), bounds, pixelRatio);
}
