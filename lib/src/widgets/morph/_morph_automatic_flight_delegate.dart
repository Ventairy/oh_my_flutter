part of 'morph.dart';

final class _MorphAutomaticFlightDelegate extends MorphFlightDelegate<_MorphAutomaticProperties> {
  const _MorphAutomaticFlightDelegate({
    required this.switchThreshold,
    required this.nonMorphDescendantsTransition,
  });

  final double switchThreshold;
  final AnimatedSwitcherTransitionBuilder? nonMorphDescendantsTransition;

  @override
  _MorphAutomaticProperties properties(MorphEndpointContext endpoint) {
    final capturedEnvironment = _MorphCapturedEnvironment(endpoint.context);
    final hasUnsupportedContainerTransform = switch (endpoint.child) {
      Container(transform: final Matrix4 _) => true,
      _ => false,
    };
    if (!endpoint._hasSupportedBuiltInTransform || hasUnsupportedContainerTransform) {
      return _rawProperties(endpoint, capturedEnvironment);
    }
    try {
      return _MorphAutomaticProperties(
        MorphChildFlightDelegate._properties(
          context: endpoint.context,
          widget: endpoint.child,
          rect: Offset.zero & endpoint.overlayBounds.size,
          axisScale: endpoint.axisScale,
          switchThreshold: switchThreshold,
          capturedEnvironment: capturedEnvironment,
          renderObject: endpoint._renderObject,
          specializeDecoratedBox: true,
          captureTextConstraintWidth: false,
        ),
      );
    } on Object catch (exception) {
      if (exception is! ArgumentError) rethrow;
      return _rawProperties(endpoint, capturedEnvironment);
    }
  }

  _MorphAutomaticProperties _rawProperties(
    MorphEndpointContext endpoint,
    _MorphCapturedEnvironment capturedEnvironment,
  ) {
    return _MorphAutomaticProperties(
      MorphChildFlightDelegate._rawProperties(
        widget: endpoint.child,
        rect: Offset.zero & endpoint.overlayBounds.size,
        capturedEnvironment: capturedEnvironment,
      ),
    );
  }

  @override
  _MorphAutomaticProperties lerp(
    _MorphAutomaticProperties source,
    _MorphAutomaticProperties destination,
    double progress,
  ) {
    if (!_sharesSpecialization(source, destination)) {
      return progress < switchThreshold ? source : destination;
    }
    return _MorphAutomaticProperties(
      MorphChildFlightDelegate.lerp(
        source: source.child,
        destination: destination.child,
        progress: progress,
        switchThreshold: switchThreshold,
        transitionEnabled: nonMorphDescendantsTransition != null,
      ),
    );
  }

  @override
  Widget buildFlight(
    BuildContext context,
    MorphFlight<_MorphAutomaticProperties> flight,
  ) {
    final specialized = _specializedFlight(flight);
    if (specialized != null) {
      return specialized.delegate._buildErasedFlight(
        context,
        specialized.flight,
      );
    }
    return _MorphAutomaticFlight(
      flight: flight,
      switchThreshold: switchThreshold,
      transitionBuilder: nonMorphDescendantsTransition,
    );
  }

  ({
    MorphFlightDelegate<Object?> delegate,
    MorphFlight<Object?> flight,
  })?
  _specializedFlight(MorphFlight<Object?> flight) {
    final source = flight._sourceProperties;
    final destination = flight._destinationProperties;
    if (source is! _MorphAutomaticProperties || destination is! _MorphAutomaticProperties) {
      return null;
    }

    final sourceText = source.child.text;
    final destinationText = destination.child.text;
    if (sourceText != null && destinationText != null) {
      final delegate = MorphTextFlightDelegate(
        switchThreshold: switchThreshold,
      );
      return (
        delegate: delegate,
        flight: _typedFlight(
          flight,
          source: sourceText,
          destination: destinationText,
          delegate: delegate,
        ),
      );
    }

    final sourceContainer = source.child.container;
    final destinationContainer = destination.child.container;
    if (sourceContainer != null && destinationContainer != null) {
      final delegate = MorphContainerFlightDelegate(
        switchThreshold: switchThreshold,
        nonMorphDescendantsTransition: nonMorphDescendantsTransition,
      );
      return (
        delegate: delegate,
        flight: _typedFlight(
          flight,
          source: sourceContainer,
          destination: destinationContainer,
          delegate: delegate,
        ),
      );
    }

    final sourceColumn = source.child.column;
    final destinationColumn = destination.child.column;
    if (sourceColumn != null && destinationColumn != null) {
      final delegate = MorphColumnFlightDelegate(
        switchThreshold: switchThreshold,
        nonMorphDescendantsTransition: nonMorphDescendantsTransition,
      );
      return (
        delegate: delegate,
        flight: _typedFlight(
          flight,
          source: sourceColumn,
          destination: destinationColumn,
          delegate: delegate,
        ),
      );
    }
    return null;
  }

  MorphFlight<Object?> _typedFlight<T>(
    MorphFlight<Object?> flight, {
    required T source,
    required T destination,
    required MorphFlightDelegate<T> delegate,
  }) {
    final sourceEndpoint = flight.source;
    final destinationEndpoint = flight.destination;
    return MorphFlight<T>(
      source: MorphEndpoint<T>(
        properties: source,
        bounds: sourceEndpoint.bounds,
        localSize: sourceEndpoint.localSize,
        transform: sourceEndpoint.transform,
        axisScale: sourceEndpoint.axisScale,
      ),
      destination: MorphEndpoint<T>(
        properties: destination,
        bounds: destinationEndpoint.bounds,
        localSize: destinationEndpoint.localSize,
        transform: destinationEndpoint.transform,
        axisScale: destinationEndpoint.axisScale,
      ),
      kind: flight.kind,
      animation: flight.animation,
      flightDelegate: delegate,
    ).._geometry = flight._geometry;
  }

  bool _sharesSpecialization(
    _MorphAutomaticProperties source,
    _MorphAutomaticProperties destination,
  ) {
    return (source.child.text != null && destination.child.text != null) ||
        (source.child.container != null && destination.child.container != null) ||
        (source.child.column != null && destination.child.column != null);
  }
}
