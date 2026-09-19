part of 'morph.dart';

final class _MorphTargetGroup {
  new(this.tag);

  final Object tag;
  final List<_MorphEndpointHandle> endpoints = [];
  final Map<MorphTarget, _MorphTargetProgress> progress = {};
  _MorphSiblingTransition? siblingTransition;
  _MorphEndpointHandle? owner;
  _MorphEndpointHandle? selected;
  int navigationRevision = -1;

  void register(_MorphEndpointHandle endpoint) {
    final previousIndex = endpoints.indexWhere(
      (previous) =>
          !previous.disposed &&
          identical(previous.target, endpoint.target) &&
          identical(previous.route, endpoint.route),
    );
    if (previousIndex < 0) {
      endpoints.add(endpoint);
      return;
    }
    endpoint.registrationOrder = endpoints[previousIndex].registrationOrder;
    endpoints.insert(previousIndex + 1, endpoint);
  }
}
