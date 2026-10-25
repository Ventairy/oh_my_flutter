part of 'contour.dart';

@immutable
class _ContourShadowAtlasKey {
  new({
    required Object maskIdentity,
    required bool nativeMask,
    required this.minimumAmount,
    required Offset origin,
    required List<Shadow> shadows,
    required Rect bounds,
    required double pixelRatio,
  }) : _mask = _ContourShadowImageKey(
         maskIdentity: maskIdentity,
         amount: minimumAmount,
         nativeMask: nativeMask,
         shadows: shadows,
         bounds: bounds,
         pixelRatio: pixelRatio,
       ),
       _origin = Offset(origin.dx, origin.dy);

  final _ContourShadowImageKey _mask;
  final Offset _origin;
  final double minimumAmount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _ContourShadowAtlasKey && _mask == other._mask && _origin == other._origin;

  @override
  int get hashCode => Object.hash(_mask, _origin);
}
