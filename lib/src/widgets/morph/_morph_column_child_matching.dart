part of 'morph.dart';

final class _MorphColumnChildMatching {
  _MorphColumnChildMatching({
    required List<MorphChildProperties> source,
    required List<MorphChildProperties> destination,
  }) : _destinationIndicesBySource = List<int?>.filled(
         source.length,
         null,
         growable: false,
       ),
       _matchedDestinations = List<bool>.filled(
         destination.length,
         false,
         growable: false,
       ) {
    final keyedDestinations = <Key, List<int>>{};
    final unkeyedDestinations = <int>[];
    for (var index = 0; index < destination.length; index += 1) {
      final key = destination[index].key;
      if (key == null) {
        unkeyedDestinations.add(index);
      } else {
        (keyedDestinations[key] ??= <int>[]).add(index);
      }
    }

    final keyedOffsets = <Key, int>{};
    var unkeyedOffset = 0;
    for (var index = 0; index < source.length; index += 1) {
      final key = source[index].key;
      int? destinationIndex;
      if (key == null) {
        if (unkeyedOffset < unkeyedDestinations.length) {
          destinationIndex = unkeyedDestinations[unkeyedOffset];
          unkeyedOffset += 1;
        }
      } else {
        final candidates = keyedDestinations[key];
        final offset = keyedOffsets[key] ?? 0;
        if (candidates != null && offset < candidates.length) {
          destinationIndex = candidates[offset];
          keyedOffsets[key] = offset + 1;
        }
      }
      if (destinationIndex == null) continue;
      _destinationIndicesBySource[index] = destinationIndex;
      _matchedDestinations[destinationIndex] = true;
    }
  }

  final List<int?> _destinationIndicesBySource;
  final List<bool> _matchedDestinations;

  int? destinationIndexForSource(int sourceIndex) => _destinationIndicesBySource[sourceIndex];

  bool isDestinationMatched(int destinationIndex) => _matchedDestinations[destinationIndex];
}
