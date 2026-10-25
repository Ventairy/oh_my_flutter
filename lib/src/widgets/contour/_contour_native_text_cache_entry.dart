part of 'contour.dart';

class _ContourNativeTextCacheEntry {
  const new(
    this.geometry,
    this.estimatedBytes, {
    required this.native,
    required this.nativeMaskSourceId,
    required this.nativeMaskSourceBytes,
    this.proof,
    this.onPresented,
  }) : assert(!native || nativeMaskSourceId != null, 'A native mask requires an accepted proof identity.');

  // Published paths are never mutated. The native mask paints the exact glyph,
  // while this actual captured geometry retains its proven overflow bounds.
  final ContourGeometry geometry;
  final Future<_ContourNativeTextCacheEntry?>? proof;
  final VoidCallback? onPresented;
  final bool native;

  // Native curves belong to the accepted proof, independently of sampled
  // geometry that may later be shared between visually equivalent sources.
  final Object? nativeMaskSourceId;
  final int nativeMaskSourceBytes;

  // Includes a conservative allowance for the native path's geometry.
  final int estimatedBytes;
}
