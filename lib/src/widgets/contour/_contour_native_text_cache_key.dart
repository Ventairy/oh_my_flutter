part of 'contour.dart';

@immutable
class _ContourNativeTextCacheKey {
  const new(this.value, this.estimatedBytes);

  final Object value;
  final int estimatedBytes;

  @override
  bool operator ==(Object other) => other is _ContourNativeTextCacheKey && value == other.value;

  @override
  int get hashCode => value.hashCode;
}
