part of 'morph.dart';

extension _MorphAlternativeMatching on _MorphCoordinator {
  void _indexTargets(_MorphEndpointHandle endpoint) {
    for (final target in endpoint.targets) {
      endpoint.observer?._trackTarget(target);
      final appearances = _appearancesByTag.putIfAbsent(target, () => []);
      if (!appearances.contains(endpoint)) appearances.add(endpoint);
      appearances.sort((a, b) => a.registrationOrder.compareTo(b.registrationOrder));
    }
  }

  void _unindexTargets(_MorphEndpointHandle endpoint) {
    for (final target in endpoint.targets) {
      final appearances = _appearancesByTag[target];
      appearances?.remove(endpoint);
      if (appearances?.isEmpty ?? false) _appearancesByTag.remove(target);
    }
  }

  void updateTargets(_MorphEndpointHandle endpoint, List<MorphTarget> targets) {
    _unindexTargets(endpoint);
    final retained = targets.contains(endpoint.target);
    if (!retained) {
      final flight = _removeFlight(endpoint.tag);
      flight?.cancelForRetarget();
      if (flight != null) {
        final source = flight.sourceHandle;
        if (source != null) source.visibility.hidden = false;
        flight.destinationHandle.visibility.hidden = false;
      }
    }
    endpoint.targets = targets;
    _indexTargets(endpoint);
    if (!retained) {
      _selectTarget(endpoint, targets.first);
      _groups[endpoint.tag]!
        ..selected = endpoint
        ..navigationRevision = endpoint.observer?._request?.revision ?? -1;
    }
    endpoint.alternativesResolved = true;
    for (final target in targets) {
      final group = _groups[target];
      if (group != null) _scheduleReconciliation(group);
    }
    _removeOverlayWhenIdle();
  }

  void _selectTarget(_MorphEndpointHandle endpoint, MorphTarget target) {
    if (identical(endpoint.target, target)) return;
    final previous = _groups[endpoint.tag];
    previous?.endpoints.remove(endpoint);
    if (previous != null) {
      _pruneGroup(previous);
      if (_groups.containsKey(previous.tag)) _pendingGroups.add(previous);
    }
    endpoint
      ..target = target
      ..configurationChanged();
    final group = _groups.putIfAbsent(target, () => _MorphTargetGroup(target));
    group.endpoints.add(endpoint);
    group.endpoints.sort((a, b) => a.registrationOrder.compareTo(b.registrationOrder));
    _pendingGroups.add(group);
  }

  _MorphEndpointHandle? _lastAppearance(Object tag, Route<Object?>? route) {
    final candidates = _appearancesByTag[tag];
    if (candidates == null) return null;
    // Use the existing ancestry and same-tag appearance rules for alternatives.
    final group = _MorphTargetGroup(tag)..endpoints.addAll(candidates);
    return _lastMounted(group, route);
  }

  void _resolveTargetAlternatives() {
    final alternatives = _appearancesByTag.values
        .expand((appearances) => appearances)
        .where((endpoint) => endpoint.targets.length > 1)
        .toSet();
    if (alternatives.isEmpty) return;
    final tags = alternatives.expand((endpoint) => endpoint.targets.map((target) => target)).toSet();
    final destinations =
        tags
            .expand((tag) => _appearancesByTag[tag] ?? <_MorphEndpointHandle>[])
            .where((endpoint) => endpoint.active && !endpoint.disposed)
            .toSet()
            .toList()
          ..sort((a, b) => a.registrationOrder.compareTo(b.registrationOrder));
    final reserved = <_MorphEndpointHandle>{};
    for (final destination in destinations) {
      final request = destination.observer?._request;
      if (request?.cancelled ?? false) continue;
      final newNavigation =
          request != null && request.source != null && _groups[destination.tag]?.navigationRevision != request.revision;
      final returning = destination.targets.any((target) {
        final selected = _groups[target]?.selected;
        return selected != null && !selected.active;
      });
      if (!newNavigation && destination.alternativesResolved && !returning) continue;
      final destinationRoute = newNavigation ? request.destination : destination.observer?._currentRoute;
      if (!identical(destination.route, destinationRoute) || reserved.contains(destination)) continue;
      destination.alternativeMatchAvailable = false;
      for (final target in destination.targets) {
        final acceptedTarget = newNavigation ? request.acceptedTargets[destination] : null;
        if (acceptedTarget != null && !identical(acceptedTarget, target)) continue;
        if (!identical(_lastAppearance(target, destinationRoute), destination)) continue;
        final source = _sourceForMatch(destination, target, request: newNavigation ? request : null);
        if (source == null || identical(source, destination) || reserved.contains(source)) continue;
        if (!newNavigation && !identical(source.route, destination.route)) continue;
        final sourceTarget = source.targets.where((candidate) => identical(candidate, target)).firstOrNull;
        if (sourceTarget == null) continue;
        // An already accepted relationship owns both visuals until it hands off.
        // Reorders and unrelated registrations cannot start a second entrance.
        if ((_flightUses(source) && source.tag != target) || (_flightUses(destination) && destination.tag != target)) {
          continue;
        }
        if (!source.flightsEnabled ||
            !destination.flightsEnabled ||
            source.animationsDisabled ||
            destination.animationsDisabled ||
            !_delegatesAreCompatible(source.delegate, destination.delegate)) {
          continue;
        }
        if (!_canMatch(
          source,
          destination,
          sourceTarget: sourceTarget,
          destinationTarget: target,
          request: newNavigation ? request : null,
        )) {
          continue;
        }
        if (!_flightUses(source) &&
            (_capture(source, target: sourceTarget, reuseSameFrame: true) == null ||
                _capture(destination, target: target, reuseSameFrame: true) == null)) {
          continue;
        }
        destination.alternativeMatchAvailable = true;
        _selectTarget(source, sourceTarget);
        _selectTarget(destination, target);
        final selectedGroup = _groups[target]!;
        if (identical(source.route, destination.route)) selectedGroup.selected = source;
        _pendingGroups.add(selectedGroup);
        reserved.addAll([source, destination]);
        break;
      }
    }
    for (final endpoint in destinations) {
      endpoint.alternativesResolved = true;
    }
  }
}
