part of 'morph.dart';

/// Defines a column-specific Morph transition.
final class MorphColumnFlightDelegate extends MorphFlightDelegate<MorphColumnProperties> {
  /// Creates a transition for a vertical column and its children.
  const MorphColumnFlightDelegate({
    this.switchThreshold = 0.5,
    this.nonMorphDescendantsTransition,
  }) : assert(
         switchThreshold >= 0 && switchThreshold <= 1,
         'switchThreshold must be between 0 and 1.',
       );

  /// Progress at which matched children switch non-interpolated values to the
  /// destination.
  final double switchThreshold;

  /// Transition applied when non-Morph descendant content changes.
  ///
  /// Nested Morph descendants continue using their own transitions. When the
  /// source and destination specify different builders, the source builder is
  /// used.
  final AnimatedSwitcherTransitionBuilder? nonMorphDescendantsTransition;

  @override
  MorphColumnProperties properties(MorphEndpointContext endpoint) {
    if (!endpoint._hasSupportedBuiltInTransform) {
      throw ArgumentError.value(
        endpoint.transform,
        'endpoint.transform',
        'Built-in Column Morph supports axis-aligned translation and positive scale only.',
      );
    }
    final widget = endpoint.child;
    final renderObject = endpoint._renderObject;
    if (widget is! Column || renderObject is! RenderFlex) {
      throw ArgumentError.value(
        widget,
        'endpoint.child',
        'MorphColumnFlightDelegate requires a Column child.',
      );
    }

    return _captureColumn(
      context: endpoint.context,
      column: widget,
      renderObject: renderObject,
      axisScale: endpoint.axisScale,
      switchThreshold: switchThreshold,
      capturedEnvironment: _MorphCapturedEnvironment(endpoint.context),
    );
  }

  /// Returns the visual values used to transition [column].
  static MorphColumnProperties captureColumn({
    required BuildContext context,
    required Column column,
    required RenderFlex renderObject,
    required Offset axisScale,
    required double switchThreshold,
  }) {
    return _captureColumn(
      context: context,
      column: column,
      renderObject: renderObject,
      axisScale: axisScale,
      switchThreshold: switchThreshold,
      capturedEnvironment: _MorphCapturedEnvironment(context),
    );
  }

  static MorphColumnProperties _captureColumn({
    required BuildContext context,
    required Column column,
    required RenderFlex renderObject,
    required Offset axisScale,
    required double switchThreshold,
    required _MorphCapturedEnvironment capturedEnvironment,
  }) {
    final children = <MorphChildProperties>[];
    var renderChild = renderObject.firstChild;
    for (var index = 0; index < column.children.length && renderChild != null; index += 1) {
      final parentData = renderChild.parentData! as FlexParentData;
      final offset = parentData.offset;
      final childSize = renderChild.size;
      final rect = Rect.fromLTWH(
        offset.dx * axisScale.dx,
        offset.dy * axisScale.dy,
        childSize.width * axisScale.dx,
        childSize.height * axisScale.dy,
      );
      children.add(
        MorphChildFlightDelegate._properties(
          context: context,
          widget: column.children[index],
          rect: rect,
          axisScale: axisScale,
          switchThreshold: switchThreshold,
          capturedEnvironment: capturedEnvironment,
          renderObject: renderChild,
        ),
      );
      renderChild = renderObject.childAfter(renderChild);
    }

    return MorphColumnProperties(
      children: List.unmodifiable(children),
      switchThreshold: switchThreshold,
    );
  }

  @override
  MorphColumnProperties lerp(
    MorphColumnProperties source,
    MorphColumnProperties destination,
    double progress,
  ) {
    if (progress <= 0) return source;
    if (progress >= 1) return destination;
    return _MorphColumnFlightPlan(
      source: source,
      destination: destination,
      transitionEnabled: nonMorphDescendantsTransition != null,
    ).lerp(progress);
  }

  Widget _buildProperties(
    BuildContext context,
    MorphColumnProperties properties, {
    AnimatedSwitcherTransitionBuilder? nonMorphDescendantsTransition,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: _buildPositionedChildren(
        context,
        properties.children,
        nonMorphDescendantsTransition: nonMorphDescendantsTransition,
      ),
    );
  }

  @override
  Widget buildFlight(
    BuildContext context,
    MorphFlight<MorphColumnProperties> flight,
  ) {
    final plan = _MorphCompoundFlightPlan.forColumn(
      source: flight.source.properties,
      destination: flight.destination.properties,
      textDirection: Directionality.of(context),
    );
    if (plan != null) {
      return _MorphCompoundFlight(
        animation: flight.animation,
        plan: plan,
      );
    }
    final hybridPlan = _MorphHybridColumnFlightPlan.tryCreate(
      source: flight.source.properties,
      destination: flight.destination.properties,
      textDirection: Directionality.of(context),
    );
    if (hybridPlan != null) {
      return _MorphHybridColumnFlight(
        animation: flight.animation,
        plan: hybridPlan,
        transitionBuilder: nonMorphDescendantsTransition,
      );
    }
    return _MorphColumnFlight(
      delegate: this,
      flight: flight,
      nonMorphDescendantsTransition: nonMorphDescendantsTransition,
    );
  }

  List<Widget> _buildPositionedChildren(
    BuildContext context,
    List<MorphChildProperties> properties, {
    AnimatedSwitcherTransitionBuilder? nonMorphDescendantsTransition,
  }) {
    final children = <Widget>[];
    Rect? previousLayoutRect;
    var previousPaintBottom = 0.0;
    for (final properties in properties) {
      final previousRect = previousLayoutRect;
      final gap = previousRect == null ? 0.0 : properties.rect.top - previousRect.bottom;
      final top = previousRect == null ? properties.rect.top : math.max(properties.rect.top, previousPaintBottom + gap);
      final estimatedHeight = properties.text == null ? properties.rect.height : _estimatedTextHeight(properties);
      children.add(
        _buildPositionedChild(
          context,
          properties,
          top: top,
          nonMorphDescendantsTransition: nonMorphDescendantsTransition,
        ),
      );
      previousLayoutRect = properties.rect;
      previousPaintBottom = top + estimatedHeight;
    }
    return children;
  }

  Widget _buildPositionedChild(
    BuildContext context,
    MorphChildProperties properties, {
    required double top,
    AnimatedSwitcherTransitionBuilder? nonMorphDescendantsTransition,
  }) {
    final child = MorphChildFlightDelegate.build(
      context,
      properties,
      nonMorphDescendantsTransition: nonMorphDescendantsTransition,
    );
    if (properties.text != null) {
      return Positioned(
        left: properties.rect.left,
        top: top,
        width: properties.rect.width,
        child: child,
      );
    }
    return Positioned.fromRect(
      rect: Rect.fromLTWH(
        properties.rect.left,
        top,
        properties.rect.width,
        properties.rect.height,
      ),
      child: ClipRect(
        child: Align(alignment: Alignment.topLeft, child: child),
      ),
    );
  }

  double _estimatedTextHeight(MorphChildProperties properties) {
    final text = properties.text!;
    return text.estimatedHeight + properties.padding.vertical;
  }
}
