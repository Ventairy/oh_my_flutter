part of 'morph.dart';

final class _MorphColumnChildMatching {
  _MorphColumnChildMatching({
    required List<MorphChildProperties> source,
    required List<MorphChildProperties> destination,
  }) : _sharedChildCount = math.min(source.length, destination.length);

  final int _sharedChildCount;

  int? destinationIndexForSource(int sourceIndex) {
    return sourceIndex < _sharedChildCount ? sourceIndex : null;
  }

  bool isDestinationMatched(int destinationIndex) {
    return destinationIndex < _sharedChildCount;
  }
}
