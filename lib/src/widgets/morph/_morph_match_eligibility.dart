part of 'morph.dart';

extension _MorphMatchEligibility on _MorphCoordinator {
  _MorphEndpointHandle? _sourceForMatch(
    _MorphEndpointHandle destination,
    MorphTarget target, {
    _MorphNavigationRequest? request,
  }) {
    final group = _groups[target];
    if (request != null && request.source != null) {
      return _lastAppearance(target, request.source) ??
          (identical(group?.selected?.route, request.source) ? group?.selected : null);
    }
    return (identical(group?.selected, destination) && !destination.alternativesResolved ? null : group?.selected) ??
        _appearancesByTag[target]
            ?.where(
              (candidate) =>
                  !identical(candidate, destination) &&
                  identical(candidate.route, destination.route) &&
                  candidate.registrationOrder < destination.registrationOrder,
            )
            .lastOrNull;
  }

  // Preparation only controls live painting. Capture and reservation still
  // belong to reconciliation after layout, including alternative fallback.
  MorphTarget? _findEligibleIncomingTarget(_MorphEndpointHandle destination) {
    if (!destination.flightsEnabled || destination.animationsDisabled) return null;
    final request = destination.observer?._request;
    final isNavigation =
        request != null && request.source != null && _groups[destination.tag]?.navigationRevision != request.revision;
    if (isNavigation && (request.cancelled || !identical(destination.route, request.destination))) return null;
    for (final target in destination.targets) {
      final source = _sourceForMatch(destination, target, request: isNavigation ? request : null);
      if (source == null ||
          identical(source, destination) ||
          (!isNavigation && !identical(source.route, destination.route))) {
        continue;
      }
      final sourceTarget = source.targets.where((candidate) => identical(candidate, target)).firstOrNull;
      if (sourceTarget == null ||
          !source.flightsEnabled ||
          source.animationsDisabled ||
          !_delegatesAreCompatible(source.delegate, destination.delegate)) {
        continue;
      }
      if (_canMatch(
        source,
        destination,
        sourceTarget: sourceTarget,
        destinationTarget: target,
        request: isNavigation ? request : null,
      )) {
        return target;
      }
    }
    return null;
  }

  bool _canMatch(
    _MorphEndpointHandle source,
    _MorphEndpointHandle destination, {
    MorphTarget? sourceTarget,
    MorphTarget? destinationTarget,
    _MorphNavigationRequest? request,
  }) {
    final departing = sourceTarget ?? source.target;
    final arriving = destinationTarget ?? destination.target;
    if (departing.canMatch == null &&
        arriving.canMatch == null &&
        destination.owner.widget.canMatch == null &&
        source.owner.widget.canMatch == null) {
      return true;
    }
    final decisions = request?.matchDecisions ?? _localMatchDecisions;
    return decisions.putIfAbsent((source, destination, arriving), () {
      final context = MorphMatchContext(
        sourceRoute: source.route,
        destinationRoute: destination.route,
        operation: request?.operation ?? .local,
      );
      return _invokeMatchPredicate(arriving, context) &&
          _invokeAppearancePredicate(destination, arriving, context) &&
          _invokeAppearancePredicate(source, departing, context);
    });
  }

  bool _invokeAppearancePredicate(
    _MorphEndpointHandle endpoint,
    MorphTarget target,
    MorphMatchContext context,
  ) {
    try {
      return endpoint.owner.widget.canMatch?.call(target, context) ?? true;
    } on Object catch (exception, stack) {
      reportCallbackError(tag: target.tag, callback: 'Morph.canMatch', exception: exception, stack: stack);
      return false;
    }
  }

  bool _invokeMatchPredicate(MorphTarget target, MorphMatchContext context) {
    try {
      return target.canMatch?.call(context) ?? true;
    } on Object catch (exception, stack) {
      reportCallbackError(tag: target.tag, callback: 'canMatch', exception: exception, stack: stack);
      return false;
    }
  }
}
