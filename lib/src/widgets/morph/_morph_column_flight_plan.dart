part of 'morph.dart';

class _MorphColumnFlightPlan {
  _MorphColumnFlightPlan({
    required this.source,
    required this.destination,
    required this.transitionEnabled,
  }) : _matching = _MorphColumnChildMatching(
         source: source.children,
         destination: destination.children,
       );

  final MorphColumnProperties source;
  final MorphColumnProperties destination;
  final bool transitionEnabled;
  final _MorphColumnChildMatching _matching;

  MorphColumnProperties lerp(double progress) {
    if (progress <= 0) return source;
    if (progress >= 1) return destination;

    final children = <MorphChildProperties>[];
    for (var sourceIndex = 0; sourceIndex < source.children.length; sourceIndex += 1) {
      final destinationIndex = _matching.destinationIndexForSource(sourceIndex);
      if (destinationIndex == null) {
        if (progress <= source.switchThreshold) {
          children.add(
            MorphChildFlightDelegate._departing(
              properties: source.children[sourceIndex],
              progress: progress,
              threshold: source.switchThreshold,
              transitionEnabled: transitionEnabled,
            ),
          );
        }
        continue;
      }
      children.add(
        MorphChildFlightDelegate.lerp(
          source: source.children[sourceIndex],
          destination: destination.children[destinationIndex],
          progress: progress,
          switchThreshold: source.switchThreshold,
          transitionEnabled: transitionEnabled,
        ),
      );
    }

    if (progress >= source.switchThreshold) {
      for (var destinationIndex = 0; destinationIndex < destination.children.length; destinationIndex += 1) {
        if (!_matching.isDestinationMatched(destinationIndex)) {
          children.add(
            MorphChildFlightDelegate._arriving(
              properties: destination.children[destinationIndex],
              progress: progress,
              threshold: source.switchThreshold,
              transitionEnabled: transitionEnabled,
            ),
          );
        }
      }
    }

    return MorphColumnProperties(
      children: List.unmodifiable(children),
      switchThreshold: source.switchThreshold,
    );
  }
}
