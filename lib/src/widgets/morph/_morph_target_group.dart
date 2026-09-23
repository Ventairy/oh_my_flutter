part of 'morph.dart';

final class _MorphTargetGroup {
  new(this.tag);

  final Object tag;
  final List<_MorphEndpointHandle> endpoints = [];
  _MorphEndpointHandle? owner;
  _MorphEndpointHandle? selected;
  int navigationRevision = -1;

  void register(_MorphEndpointHandle endpoint) {
    endpoints.add(endpoint);
  }
}
