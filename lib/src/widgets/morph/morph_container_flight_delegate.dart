part of 'morph.dart';

/// Defines a container-specific Morph transition.
final class MorphContainerFlightDelegate extends MorphFlightDelegate<MorphContainerProperties> {
  /// Creates a transition for containers and decorated boxes.
  const MorphContainerFlightDelegate({
    this.switchThreshold = 0.5,
    this.nonMorphDescendantsTransition,
  }) : assert(
         switchThreshold >= 0 && switchThreshold <= 1,
         'switchThreshold must be between 0 and 1.',
       );

  /// Progress at which non-interpolated values switch to the destination.
  final double switchThreshold;

  /// Transition applied when non-Morph descendant content changes.
  ///
  /// Nested Morph descendants continue using their own transitions. When the
  /// source and destination specify different builders, the source builder is
  /// used.
  final AnimatedSwitcherTransitionBuilder? nonMorphDescendantsTransition;

  @override
  MorphContainerProperties properties(MorphEndpointContext endpoint) {
    if (!endpoint._hasSupportedBuiltInTransform) {
      throw ArgumentError.value(
        endpoint.transform,
        'endpoint.transform',
        'Built-in Container Morph supports axis-aligned translation and positive scale only.',
      );
    }
    final child = endpoint.child;
    final capturedEnvironment = _MorphCapturedEnvironment(endpoint.context);
    return switch (child) {
      Container() => _captureEndpointContainer(endpoint, child, capturedEnvironment),
      DecoratedBox() => _captureDecoratedBox(
        context: endpoint.context,
        decoratedBox: child,
        size: endpoint.overlayBounds.size,
        axisScale: endpoint.axisScale,
        switchThreshold: switchThreshold,
        capturedEnvironment: capturedEnvironment,
        renderObject: endpoint._renderObject,
      ),
      _ => throw ArgumentError.value(
        child,
        'endpoint.child',
        'MorphContainerFlightDelegate requires a Container or DecoratedBox child.',
      ),
    };
  }

  MorphContainerProperties _captureEndpointContainer(
    MorphEndpointContext endpoint,
    Container container,
    _MorphCapturedEnvironment capturedEnvironment,
  ) {
    if (container.transform != null) {
      throw ArgumentError.value(
        container.transform,
        'endpoint.child.transform',
        'Container.transform is not supported by the built-in Container Morph. '
            'Apply an axis-aligned Transform outside the Morph endpoint instead.',
      );
    }
    return _captureContainer(
      context: endpoint.context,
      container: container,
      size: endpoint.overlayBounds.size,
      axisScale: endpoint.axisScale,
      switchThreshold: switchThreshold,
      capturedEnvironment: capturedEnvironment,
      renderObject: endpoint._renderObject,
    );
  }

  /// Returns the visual values used to transition [decoratedBox].
  static MorphContainerProperties captureDecoratedBox({
    required BuildContext context,
    required DecoratedBox decoratedBox,
    required Size size,
    required Offset axisScale,
    required double switchThreshold,
    RenderBox? renderObject,
  }) {
    return _captureDecoratedBox(
      context: context,
      decoratedBox: decoratedBox,
      size: size,
      axisScale: axisScale,
      switchThreshold: switchThreshold,
      capturedEnvironment: _MorphCapturedEnvironment(context),
      renderObject: renderObject,
    );
  }

  static MorphContainerProperties _captureDecoratedBox({
    required BuildContext context,
    required DecoratedBox decoratedBox,
    required Size size,
    required Offset axisScale,
    required double switchThreshold,
    required _MorphCapturedEnvironment capturedEnvironment,
    RenderBox? renderObject,
  }) {
    final decoration = _resolveDecoration(
      decoratedBox.decoration,
      Directionality.of(context),
      axisScale,
    );
    final content = decoratedBox.child;
    final child = content == null
        ? null
        : _captureChild(
            context: context,
            widget: content,
            rect: Offset.zero & size,
            axisScale: axisScale,
            switchThreshold: switchThreshold,
            capturedEnvironment: capturedEnvironment,
            renderObject: renderObject,
          );
    return MorphContainerProperties(
      alignment: null,
      padding: EdgeInsets.zero,
      decoration: decoratedBox.position == DecorationPosition.background ? decoration : null,
      foregroundDecoration: decoratedBox.position == DecorationPosition.foreground ? decoration : null,
      clipBehavior: Clip.none,
      child: child,
      switchThreshold: switchThreshold,
    );
  }

  /// Returns the visual values used to transition [container].
  static MorphContainerProperties captureContainer({
    required BuildContext context,
    required Container container,
    required Size size,
    required Offset axisScale,
    required double switchThreshold,
    RenderBox? renderObject,
  }) {
    return _captureContainer(
      context: context,
      container: container,
      size: size,
      axisScale: axisScale,
      switchThreshold: switchThreshold,
      capturedEnvironment: _MorphCapturedEnvironment(context),
      renderObject: renderObject,
    );
  }

  static MorphContainerProperties _captureContainer({
    required BuildContext context,
    required Container container,
    required Size size,
    required Offset axisScale,
    required double switchThreshold,
    required _MorphCapturedEnvironment capturedEnvironment,
    RenderBox? renderObject,
  }) {
    final direction = Directionality.of(context);
    final padding = container.padding?.resolve(direction) ?? EdgeInsets.zero;
    final scaleX = axisScale.dx;
    final scaleY = axisScale.dy;
    final scaledPadding = EdgeInsets.fromLTRB(
      padding.left * scaleX,
      padding.top * scaleY,
      padding.right * scaleX,
      padding.bottom * scaleY,
    );
    final decoration = _resolveDecoration(
      container.decoration ?? (container.color == null ? null : BoxDecoration(color: container.color)),
      direction,
      axisScale,
    );
    final content = container.child;
    final contentRect =
        Offset(scaledPadding.left, scaledPadding.top) &
        Size(math.max(0, size.width - scaledPadding.horizontal), math.max(0, size.height - scaledPadding.vertical));

    final child = content == null
        ? null
        : _captureChild(
            context: context,
            widget: content,
            rect: contentRect,
            axisScale: axisScale,
            switchThreshold: switchThreshold,
            capturedEnvironment: capturedEnvironment,
            renderObject: renderObject,
          );
    return MorphContainerProperties(
      alignment: container.alignment?.resolve(direction),
      padding: scaledPadding,
      decoration: decoration,
      foregroundDecoration: _resolveDecoration(
        container.foregroundDecoration,
        direction,
        axisScale,
      ),
      clipBehavior: container.clipBehavior,
      child: child,
      switchThreshold: switchThreshold,
    );
  }

  static MorphChildProperties _captureChild({
    required BuildContext context,
    required Widget widget,
    required Rect rect,
    required Offset axisScale,
    required double switchThreshold,
    required _MorphCapturedEnvironment capturedEnvironment,
    required RenderBox? renderObject,
  }) {
    if (MorphChildFlightDelegate._containsNestedMorphOrFlexParentData(widget)) {
      return MorphChildFlightDelegate._rawProperties(
        widget: widget,
        rect: rect,
        capturedEnvironment: capturedEnvironment,
      );
    }
    return MorphChildFlightDelegate._properties(
      context: context,
      widget: widget,
      rect: rect,
      axisScale: axisScale,
      switchThreshold: switchThreshold,
      capturedEnvironment: capturedEnvironment,
      renderObject: renderObject,
    );
  }

  @override
  MorphContainerProperties lerp(
    MorphContainerProperties source,
    MorphContainerProperties destination,
    double progress,
  ) {
    final threshold = source.switchThreshold;
    final showSource = progress < threshold;
    final sourceChild = source.child;
    final destinationChild = destination.child;
    final child = sourceChild != null && destinationChild != null
        ? MorphChildFlightDelegate.lerp(
            source: sourceChild,
            destination: destinationChild,
            progress: progress,
            switchThreshold: threshold,
            transitionEnabled: nonMorphDescendantsTransition != null,
          )
        : switch ((showSource, sourceChild, destinationChild)) {
            (true, final MorphChildProperties source?, _) => MorphChildFlightDelegate._departing(
              properties: source,
              progress: progress,
              threshold: threshold,
              transitionEnabled: nonMorphDescendantsTransition != null,
            ),
            (false, _, final MorphChildProperties destination?) => MorphChildFlightDelegate._arriving(
              properties: destination,
              progress: progress,
              threshold: threshold,
              transitionEnabled: nonMorphDescendantsTransition != null,
            ),
            _ => null,
          };

    return MorphContainerProperties(
      alignment: Alignment.lerp(
        source.alignment,
        destination.alignment,
        progress,
      ),
      padding: EdgeInsets.lerp(source.padding, destination.padding, progress)!,
      decoration: _lerpDecoration(
        source.decoration,
        destination.decoration,
        progress,
        showSource: showSource,
      ),
      foregroundDecoration: _lerpDecoration(
        source.foregroundDecoration,
        destination.foregroundDecoration,
        progress,
        showSource: showSource,
      ),
      clipBehavior: showSource ? source.clipBehavior : destination.clipBehavior,
      child: child,
      switchThreshold: threshold,
    );
  }

  Decoration? _lerpDecoration(
    Decoration? source,
    Decoration? destination,
    double progress, {
    required bool showSource,
  }) {
    if ((source == null || source is BoxDecoration) && (destination == null || destination is BoxDecoration)) {
      return BoxDecoration.lerp(
        source as BoxDecoration?,
        destination as BoxDecoration?,
        progress,
      );
    }
    return showSource ? source : destination;
  }

  static Decoration? _resolveDecoration(
    Decoration? decoration,
    TextDirection direction,
    Offset axisScale,
  ) {
    if (decoration is! BoxDecoration) return decoration;
    final scaleX = axisScale.dx;
    final scaleY = axisScale.dy;
    final uniformScale = math.sqrt(scaleX * scaleY);
    final resolvedRadius = decoration.borderRadius?.resolve(direction);
    final scaledRadius = resolvedRadius == null
        ? null
        : BorderRadius.only(
            topLeft: Radius.elliptical(
              resolvedRadius.topLeft.x * scaleX,
              resolvedRadius.topLeft.y * scaleY,
            ),
            topRight: Radius.elliptical(
              resolvedRadius.topRight.x * scaleX,
              resolvedRadius.topRight.y * scaleY,
            ),
            bottomLeft: Radius.elliptical(
              resolvedRadius.bottomLeft.x * scaleX,
              resolvedRadius.bottomLeft.y * scaleY,
            ),
            bottomRight: Radius.elliptical(
              resolvedRadius.bottomRight.x * scaleX,
              resolvedRadius.bottomRight.y * scaleY,
            ),
          );
    return decoration.copyWith(
      borderRadius: scaledRadius,
      border: _resolveAndScaleBorder(
        decoration.border,
        direction,
        scaleX: scaleX,
        scaleY: scaleY,
        fallbackScale: uniformScale,
      ),
      boxShadow: decoration.boxShadow
          ?.map(
            (shadow) => shadow.copyWith(
              offset: Offset(
                shadow.offset.dx * scaleX,
                shadow.offset.dy * scaleY,
              ),
              blurRadius: shadow.blurRadius * uniformScale,
              spreadRadius: shadow.spreadRadius * uniformScale,
            ),
          )
          .toList(growable: false),
      gradient: _resolveGradient(decoration.gradient, direction),
    );
  }

  static BoxBorder? _resolveAndScaleBorder(
    BoxBorder? border,
    TextDirection direction, {
    required double scaleX,
    required double scaleY,
    required double fallbackScale,
  }) {
    if (border == null) return null;
    final resolved = switch (border) {
      BorderDirectional() => Border(
        top: border.top,
        right: direction == TextDirection.ltr ? border.end : border.start,
        bottom: border.bottom,
        left: direction == TextDirection.ltr ? border.start : border.end,
      ),
      _ => border,
    };
    if (resolved is! Border) {
      return resolved.scale(fallbackScale) as BoxBorder?;
    }
    return Border(
      top: resolved.top.scale(scaleY),
      right: resolved.right.scale(scaleX),
      bottom: resolved.bottom.scale(scaleY),
      left: resolved.left.scale(scaleX),
    );
  }

  static Gradient? _resolveGradient(
    Gradient? gradient,
    TextDirection direction,
  ) {
    return switch (gradient) {
      LinearGradient() => LinearGradient(
        begin: gradient.begin.resolve(direction),
        end: gradient.end.resolve(direction),
        colors: gradient.colors,
        stops: gradient.stops,
        tileMode: gradient.tileMode,
        transform: gradient.transform,
      ),
      RadialGradient() => RadialGradient(
        center: gradient.center.resolve(direction),
        radius: gradient.radius,
        colors: gradient.colors,
        stops: gradient.stops,
        tileMode: gradient.tileMode,
        focal: gradient.focal?.resolve(direction),
        focalRadius: gradient.focalRadius,
        transform: gradient.transform,
      ),
      SweepGradient() => SweepGradient(
        center: gradient.center.resolve(direction),
        startAngle: gradient.startAngle,
        endAngle: gradient.endAngle,
        colors: gradient.colors,
        stops: gradient.stops,
        tileMode: gradient.tileMode,
        transform: gradient.transform,
      ),
      _ => gradient,
    };
  }

  Widget _buildProperties(
    BuildContext context,
    MorphContainerProperties properties, {
    AnimatedSwitcherTransitionBuilder? nonMorphDescendantsTransition,
  }) {
    final child = properties.child;
    return Container(
      alignment: properties.alignment,
      padding: properties.padding,
      decoration: properties.decoration,
      foregroundDecoration: properties.foregroundDecoration,
      clipBehavior: properties.clipBehavior,
      child: child == null
          ? null
          : MorphChildFlightDelegate.build(
              context,
              child,
              nonMorphDescendantsTransition: nonMorphDescendantsTransition,
            ),
    );
  }

  @override
  Widget buildFlight(
    BuildContext context,
    MorphFlight<MorphContainerProperties> flight,
  ) {
    final textDirection = Directionality.of(context);
    final plan = _MorphCompoundFlightPlan.forContainer(
      source: flight.source.properties,
      destination: flight.destination.properties,
      textDirection: textDirection,
    );
    if (plan != null) {
      return _MorphCompoundFlight(
        animation: flight.animation,
        plan: plan,
      );
    }
    if (nonMorphDescendantsTransition == null && flight._geometry == null) {
      final hybridPlan = _MorphHybridContainerFlightPlan.tryCreate(
        source: flight.source.properties,
        destination: flight.destination.properties,
        textDirection: textDirection,
      );
      if (hybridPlan != null) {
        return _MorphHybridContainerFlight(
          animation: flight.animation,
          plan: hybridPlan,
          transitionBuilder: null,
        );
      }
    }
    return AnimatedBuilder(
      animation: flight.animation,
      builder: (context, child) => _buildProperties(
        context,
        flight.properties,
        nonMorphDescendantsTransition: nonMorphDescendantsTransition,
      ),
    );
  }
}
