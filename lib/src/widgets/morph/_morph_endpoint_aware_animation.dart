part of 'morph.dart';

final class _MorphEndpointAwareAnimation extends Animation<double> {
  const new(this._parent, this._endpointState);

  final Animation<double> _parent;
  final _MorphFlightGeometry? _endpointState;

  @override
  void addListener(VoidCallback listener) {
    _parent.addListener(listener);
    _endpointState?.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _parent.removeListener(listener);
    _endpointState?.removeListener(listener);
  }

  @override
  void addStatusListener(AnimationStatusListener listener) {
    _parent.addStatusListener(listener);
  }

  @override
  void removeStatusListener(AnimationStatusListener listener) {
    _parent.removeStatusListener(listener);
  }

  @override
  AnimationStatus get status => _parent.status;

  @override
  double get value => _parent.value;
}

Animation<double> _morphEndpointAwareAnimation(
  Animation<double> animation,
  _MorphFlightGeometry? endpointState,
) {
  if (endpointState == null) return animation;
  if (animation case _MorphEndpointAwareAnimation(:final _endpointState)
      when identical(_endpointState, endpointState)) {
    return animation;
  }
  return _MorphEndpointAwareAnimation(animation, endpointState);
}
