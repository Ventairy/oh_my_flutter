part of 'morph.dart';

final class _MorphHybridContainerFlightPlan implements _MorphHybridRawSlotPlan {
  _MorphHybridContainerFlightPlan._({
    required MorphContainerProperties source,
    required MorphContainerProperties destination,
    required this._decorationPlan,
  }) : _sourceChild = source.child,
       _destinationChild = destination.child,
       _switchThreshold = source.switchThreshold;

  final MorphChildProperties? _sourceChild;
  final MorphChildProperties? _destinationChild;
  final double _switchThreshold;
  final _MorphCompoundFlightPlan _decorationPlan;
  double? _cachedChildRectProgress;
  late Rect _cachedChildRect;

  bool get requiresFrameLayout {
    final source = _sourceChild;
    final destination = _destinationChild;
    if (source == null || destination == null) return false;
    return source.rect.size != destination.rect.size;
  }

  static _MorphHybridContainerFlightPlan? tryCreate({
    required MorphContainerProperties source,
    required MorphContainerProperties destination,
    required TextDirection textDirection,
  }) {
    if (!_supportsShell(source) || !_supportsShell(destination)) {
      return null;
    }
    final sourceChild = source.child;
    final destinationChild = destination.child;
    if (sourceChild == null || destinationChild == null) return null;
    if (!_MorphHybridColumnFlightPlan._hasCompatibleRawWrappers(
      sourceChild,
      destinationChild,
    )) {
      return null;
    }
    if (!_supportsRawChild(sourceChild) || !_supportsRawChild(destinationChild)) {
      return null;
    }

    final decorationPlan = _MorphCompoundFlightPlan.forContainer(
      source: _withoutChild(source),
      destination: _withoutChild(destination),
      textDirection: textDirection,
    );
    if (decorationPlan == null) return null;
    return _MorphHybridContainerFlightPlan._(
      source: source,
      destination: destination,
      decorationPlan: decorationPlan,
    );
  }

  bool rawSelectionChangesBetween(double previous, double next) {
    return !identical(
      rawPropertiesAt(previous),
      rawPropertiesAt(next),
    );
  }

  @override
  MorphChildProperties? rawPropertiesAt(double progress) {
    return progress < _switchThreshold ? _sourceChild : _destinationChild;
  }

  @override
  double rawTransitionProgressAt(double progress) {
    final departing = progress < _switchThreshold;
    return MorphChildFlightDelegate._transitionProgress(
      progress: progress,
      threshold: _switchThreshold,
      departing: departing,
    );
  }

  Rect childRectAt(double progress) {
    if (_cachedChildRectProgress == progress) return _cachedChildRect;
    final source = _sourceChild;
    final destination = _destinationChild;
    final Rect result;
    if (source != null && destination != null) {
      if (identical(source.rect, destination.rect) || source.rect == destination.rect) {
        result = source.rect;
      } else {
        result = Rect.fromLTWH(
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
    } else {
      result = (source ?? destination)!.rect;
    }
    _cachedChildRectProgress = progress;
    _cachedChildRect = result;
    return result;
  }

  Size rawLayoutSizeAt(double progress) {
    if (rawPropertiesAt(progress) == null) return Size.zero;
    final size = childRectAt(progress).size;
    return Size(
      math.max(0, size.width),
      math.max(0, size.height),
    );
  }

  Rect decorationPaintBounds(Rect bounds, double progress) {
    return _decorationPlan.paintBounds(bounds, progress);
  }

  void paintBackground(
    Canvas canvas,
    Rect bounds,
    double progress,
  ) {
    _decorationPlan._paintContainerBackground(
      canvas,
      bounds,
      progress,
    );
  }

  void paintForeground(
    Canvas canvas,
    Rect bounds,
    double progress,
  ) {
    _decorationPlan._paintContainerForeground(
      canvas,
      bounds,
      progress,
    );
  }

  void dispose() {
    _decorationPlan.dispose();
  }

  static bool _supportsShell(MorphContainerProperties properties) {
    return properties.alignment == null &&
        properties.clipBehavior == Clip.none &&
        _MorphCompoundFlightPlan._supportsDecoration(
          properties.decoration,
        ) &&
        _MorphCompoundFlightPlan._supportsDecoration(
          properties.foregroundDecoration,
        );
  }

  static bool _supportsRawChild(MorphChildProperties? child) {
    if (child == null) return true;
    if (child.rect.isEmpty) return false;
    return _MorphHybridColumnFlightPlan._supportsRawIsland(child) && _supportsContainedRawWidget(child.widget);
  }

  static bool _supportsContainedRawWidget(Widget widget) {
    return switch (widget) {
      Morph() => true,
      ColoredBox(:final child) => child == null || _supportsContainedRawWidget(child),
      DecoratedBox(:final decoration, :final child) =>
        _supportsContainedDecoration(decoration) && (child == null || _supportsContainedRawWidget(child)),
      Container(
        :final decoration,
        :final foregroundDecoration,
        :final clipBehavior,
        :final child,
      ) =>
        _supportsContainedDecoration(decoration) &&
            _supportsContainedDecoration(foregroundDecoration) &&
            (clipBehavior != Clip.none && decoration != null || child == null || _supportsContainedRawWidget(child)),
      Padding(:final child) => child == null || _supportsContainedRawWidget(child),
      ConstrainedBox(:final child) => child == null || _supportsContainedRawWidget(child),
      SafeArea(:final child) => _supportsContainedRawWidget(child),
      Flexible(:final child) => _supportsContainedRawWidget(child),
      Align(
        :final child,
        :final widthFactor,
        :final heightFactor,
      ) =>
        widthFactor == null && heightFactor == null && (child == null || _supportsContainedRawWidget(child)),
      SizedBox(:final child) => child == null || _supportsContainedRawWidget(child),
      ClipRect(:final clipBehavior, :final clipper) => clipBehavior != Clip.none && clipper == null,
      ClipRRect(:final clipBehavior, :final clipper) => clipBehavior != Clip.none && clipper == null,
      ClipOval(:final clipBehavior, :final clipper) => clipBehavior != Clip.none && clipper == null,
      ClipPath(:final clipBehavior, :final clipper) => clipBehavior != Clip.none && clipper == null,
      Row(:final children) => children.every(_supportsHiddenNestedMorphLayout),
      Column(:final children) => children.every(_supportsHiddenNestedMorphLayout),
      _ => false,
    };
  }

  static bool _supportsHiddenNestedMorphLayout(Widget widget) {
    return switch (widget) {
      Morph() => true,
      Padding(:final child) => child == null || _supportsHiddenNestedMorphLayout(child),
      ConstrainedBox(:final child) => child == null || _supportsHiddenNestedMorphLayout(child),
      SafeArea(:final child) => _supportsHiddenNestedMorphLayout(child),
      Flexible(:final child) => _supportsHiddenNestedMorphLayout(child),
      Align(
        :final child,
        :final widthFactor,
        :final heightFactor,
      ) =>
        widthFactor == null && heightFactor == null && (child == null || _supportsHiddenNestedMorphLayout(child)),
      SizedBox(:final child) => child == null || _supportsHiddenNestedMorphLayout(child),
      Row(:final children) || Column(:final children) => children.every(_supportsHiddenNestedMorphLayout),
      _ => false,
    };
  }

  static bool _supportsContainedDecoration(Decoration? decoration) {
    if (decoration == null) return true;
    if (decoration is! BoxDecoration) return false;
    return decoration.image == null && decoration.border == null && decoration.boxShadow?.isNotEmpty != true;
  }

  static MorphContainerProperties _withoutChild(
    MorphContainerProperties properties,
  ) {
    return MorphContainerProperties(
      alignment: properties.alignment,
      padding: properties.padding,
      decoration: properties.decoration,
      foregroundDecoration: properties.foregroundDecoration,
      clipBehavior: properties.clipBehavior,
      child: null,
      switchThreshold: properties.switchThreshold,
    );
  }
}
