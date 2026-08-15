part of 'morph.dart';

class _MorphFlightGeometry extends ChangeNotifier {
  _MorphFlightGeometry({
    required MorphEndpoint<Object?> source,
    required MorphEndpoint<Object?> destination,
  }) : _sourceBounds = source.bounds,
       _sourceLocalSize = source.localSize,
       _sourceTransform = Matrix4.copy(source.transform),
       _sourceAxisScale = source.axisScale,
       _destinationBounds = destination.bounds,
       _destinationLocalSize = destination.localSize,
       _destinationTransform = Matrix4.copy(destination.transform),
       _destinationAxisScale = destination.axisScale;

  Rect _sourceBounds;
  Size _sourceLocalSize;
  final Matrix4 _sourceTransform;
  Offset _sourceAxisScale;
  Rect _destinationBounds;
  Size _destinationLocalSize;
  final Matrix4 _destinationTransform;
  Offset _destinationAxisScale;
  bool _disposed = false;

  Rect get sourceBounds => _sourceBounds;

  Rect get destinationBounds => _destinationBounds;

  MorphEndpoint<T> source<T>(T properties) {
    return MorphEndpoint<T>(
      properties: properties,
      bounds: _sourceBounds,
      localSize: _sourceLocalSize,
      transform: Matrix4.copy(_sourceTransform),
      axisScale: _sourceAxisScale,
    );
  }

  MorphEndpoint<T> _sourceWithOwnedTransform<T>(T properties) {
    return MorphEndpoint<T>(
      properties: properties,
      bounds: _sourceBounds,
      localSize: _sourceLocalSize,
      transform: _sourceTransform,
      axisScale: _sourceAxisScale,
    );
  }

  MorphEndpoint<T> destination<T>(T properties) {
    return MorphEndpoint<T>(
      properties: properties,
      bounds: _destinationBounds,
      localSize: _destinationLocalSize,
      transform: Matrix4.copy(_destinationTransform),
      axisScale: _destinationAxisScale,
    );
  }

  MorphEndpoint<T> _destinationWithOwnedTransform<T>(T properties) {
    return MorphEndpoint<T>(
      properties: properties,
      bounds: _destinationBounds,
      localSize: _destinationLocalSize,
      transform: _destinationTransform,
      axisScale: _destinationAxisScale,
    );
  }

  bool updateSource(_MorphEndpointGeometry value) {
    if (value.overlayBounds == _sourceBounds &&
        value.localSize == _sourceLocalSize &&
        value.axisScale == _sourceAxisScale &&
        MatrixUtils.matrixEquals(value.transform, _sourceTransform)) {
      return false;
    }
    _sourceBounds = value.overlayBounds;
    _sourceLocalSize = value.localSize;
    _sourceTransform.setFrom(value.transform);
    _sourceAxisScale = value.axisScale;
    if (!_disposed) notifyListeners();
    return true;
  }

  bool updateDestination(_MorphEndpointGeometry value) {
    if (value.overlayBounds == _destinationBounds &&
        value.localSize == _destinationLocalSize &&
        value.axisScale == _destinationAxisScale &&
        MatrixUtils.matrixEquals(value.transform, _destinationTransform)) {
      return false;
    }
    _destinationBounds = value.overlayBounds;
    _destinationLocalSize = value.localSize;
    _destinationTransform.setFrom(value.transform);
    _destinationAxisScale = value.axisScale;
    if (!_disposed) notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
