part of 'morph.dart';

final class _MorphHybridColumnChildPlan implements _MorphHybridRawSlotPlan {
  const _MorphHybridColumnChildPlan({
    required this.source,
    required this.destination,
    required this.retained,
    required this.rawSlotIndex,
    required this.switchThreshold,
  }) : assert(
         (retained == null) != (rawSlotIndex == null),
         'A hybrid child must be either retained or raw.',
       );

  final MorphChildProperties? source;
  final MorphChildProperties? destination;
  final _MorphCompoundFlightPlan? retained;
  final int? rawSlotIndex;
  final double switchThreshold;

  bool get isRaw => rawSlotIndex != null;

  bool get rawSizeChangesContinuously {
    final source = this.source;
    final destination = this.destination;
    if (!isRaw || source == null || destination == null) return false;
    return source.rect.size != destination.rect.size;
  }

  bool isVisible(double progress) {
    final retained = this.retained;
    if (retained != null) return retained._isVisible(progress);
    if (source != null && destination != null) return true;
    if (source != null) return progress <= switchThreshold;
    return progress >= switchThreshold;
  }

  Rect rectAt(double progress) {
    final retained = this.retained;
    if (retained != null) return retained._rectAt(progress);
    final source = this.source;
    final destination = this.destination;
    if (source != null && destination != null) {
      if (identical(source.rect, destination.rect) || source.rect == destination.rect) {
        return source.rect;
      }
      return Rect.fromLTWH(
        source.rect.left == destination.rect.left
            ? source.rect.left
            : ui.lerpDouble(
                source.rect.left,
                destination.rect.left,
                progress,
              )!,
        source.rect.top == destination.rect.top
            ? source.rect.top
            : ui.lerpDouble(
                source.rect.top,
                destination.rect.top,
                progress,
              )!,
        source.rect.width == destination.rect.width
            ? source.rect.width
            : math.max(
                0,
                ui.lerpDouble(
                  source.rect.width,
                  destination.rect.width,
                  progress,
                )!,
              ),
        source.rect.height == destination.rect.height
            ? source.rect.height
            : math.max(
                0,
                ui.lerpDouble(
                  source.rect.height,
                  destination.rect.height,
                  progress,
                )!,
              ),
      );
    }
    return (source ?? destination)!.rect;
  }

  @override
  MorphChildProperties? rawPropertiesAt(double progress) {
    assert(isRaw, 'Only a raw child has selectable widget properties.');
    final source = this.source;
    final destination = this.destination;
    if (source != null && destination != null) {
      return progress < switchThreshold ? source : destination;
    }
    if (source != null) {
      return progress <= switchThreshold ? source : null;
    }
    return progress >= switchThreshold ? destination : null;
  }

  @override
  double rawTransitionProgressAt(double progress) {
    assert(isRaw, 'Only a raw child has a descendant transition.');
    final source = this.source;
    final destination = this.destination;
    if (source != null && destination != null) {
      final departing = progress < switchThreshold;
      return MorphChildFlightDelegate._transitionProgress(
        progress: progress,
        threshold: switchThreshold,
        departing: departing,
      );
    }
    if (source != null) {
      return MorphChildFlightDelegate._transitionProgress(
        progress: progress,
        threshold: switchThreshold,
        departing: true,
      );
    }
    return MorphChildFlightDelegate._transitionProgress(
      progress: progress,
      threshold: switchThreshold,
      departing: false,
    );
  }

  double retainedPaintHeight(
    Canvas canvas,
    Rect rect,
    double progress, {
    required Rect owningBounds,
  }) {
    return retained!._paintChild(
      canvas,
      rect,
      progress,
      owningBounds: owningBounds,
    );
  }

  double estimatedPaintHeight(Rect rect, double progress) {
    final retained = this.retained;
    return retained == null ? rect.height : retained._estimatedPaintHeight(rect, progress);
  }

  double columnGapAfter(
    _MorphHybridColumnChildPlan previous,
    double progress,
  ) {
    final source = this.source;
    final previousSource = previous.source;
    final destination = this.destination;
    final previousDestination = previous.destination;
    final sourceGap = source == null || previousSource == null ? null : source.rect.top - previousSource.rect.bottom;
    final destinationGap = destination == null || previousDestination == null
        ? null
        : destination.rect.top - previousDestination.rect.bottom;
    return switch ((sourceGap, destinationGap)) {
      (final double source, final double destination) => ui.lerpDouble(
        source,
        destination,
        progress,
      )!,
      (final double source, null) => source,
      (null, final double destination) => destination,
      _ => 0,
    };
  }

  Rect retainedPaintBounds(
    Rect rect,
    double progress, {
    required Rect owningBounds,
  }) {
    return retained!._childPaintBounds(
      rect,
      progress,
      owningBounds: owningBounds,
    );
  }
}
