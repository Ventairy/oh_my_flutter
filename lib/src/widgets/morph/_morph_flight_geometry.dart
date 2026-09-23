part of 'morph.dart';

class _MorphFlightGeometry extends ChangeNotifier {
  new({
    required MorphEndpoint<Object?> source,
    required MorphEndpoint<Object?> destination,
  }) : _sourceEndpoint = source,
       _destinationEndpoint = destination,
       _sourceBounds = source.bounds,
       _sourceLocalSize = source.localSize,
       _sourceTransform = Matrix4.copy(source.transform),
       _sourceAxisScale = source.axisScale,
       _destinationBounds = destination.bounds,
       _destinationLocalSize = destination.localSize,
       _destinationTransform = Matrix4.copy(destination.transform),
       _destinationAxisScale = destination.axisScale;

  MorphEndpoint<Object?> _sourceEndpoint;
  MorphEndpoint<Object?> _destinationEndpoint;
  Rect _sourceBounds;
  Size _sourceLocalSize;
  final Matrix4 _sourceTransform;
  Offset _sourceAxisScale;
  Rect _destinationBounds;
  Size _destinationLocalSize;
  final Matrix4 _destinationTransform;
  Offset _destinationAxisScale;
  bool _disposed = false;
  int _revision = 0;

  int get revision => _revision;

  Rect get sourceBounds => _sourceBounds;

  Rect get destinationBounds => _destinationBounds;

  Object? get sourceProperties => _sourceEndpoint.properties;

  Object? get destinationProperties => _destinationEndpoint.properties;

  MorphEndpoint<T> source<T>() {
    return _MorphDescendantSnapshots.copy(
      _sourceEndpoint,
      MorphEndpoint<T>(
        properties: _sourceEndpoint.properties as T,
        bounds: _sourceBounds,
        localSize: _sourceLocalSize,
        transform: Matrix4.copy(_sourceTransform),
        axisScale: _sourceAxisScale,
      ),
    );
  }

  MorphEndpoint<T> _sourceWithOwnedTransform<T>() {
    return _MorphDescendantSnapshots.copy(
      _sourceEndpoint,
      MorphEndpoint<T>(
        properties: _sourceEndpoint.properties as T,
        bounds: _sourceBounds,
        localSize: _sourceLocalSize,
        transform: _sourceTransform,
        axisScale: _sourceAxisScale,
      ),
    );
  }

  MorphEndpoint<T> destination<T>() {
    return _MorphDescendantSnapshots.copy(
      _destinationEndpoint,
      MorphEndpoint<T>(
        properties: _destinationEndpoint.properties as T,
        bounds: _destinationBounds,
        localSize: _destinationLocalSize,
        transform: Matrix4.copy(_destinationTransform),
        axisScale: _destinationAxisScale,
      ),
    );
  }

  MorphEndpoint<T> _destinationWithOwnedTransform<T>() {
    return _MorphDescendantSnapshots.copy(
      _destinationEndpoint,
      MorphEndpoint<T>(
        properties: _destinationEndpoint.properties as T,
        bounds: _destinationBounds,
        localSize: _destinationLocalSize,
        transform: _destinationTransform,
        axisScale: _destinationAxisScale,
      ),
    );
  }

  void updateSourceEndpoint(MorphEndpoint<Object?> value) {
    _sourceEndpoint = value;
    _sourceBounds = value.bounds;
    _sourceLocalSize = value.localSize;
    _sourceTransform.setFrom(value.transform);
    _sourceAxisScale = value.axisScale;
    _notifyEndpointChanged();
  }

  void updateDestinationEndpoint(MorphEndpoint<Object?> value) {
    _destinationEndpoint = value;
    _destinationBounds = value.bounds;
    _destinationLocalSize = value.localSize;
    _destinationTransform.setFrom(value.transform);
    _destinationAxisScale = value.axisScale;
    _notifyEndpointChanged();
  }

  bool sourceMatches(_MorphEndpointGeometry value) =>
      value.overlayBounds == _sourceBounds &&
      value.localSize == _sourceLocalSize &&
      value.axisScale == _sourceAxisScale &&
      MatrixUtils.matrixEquals(value.transform, _sourceTransform);

  bool destinationMatches(_MorphEndpointGeometry value) =>
      value.overlayBounds == _destinationBounds &&
      value.localSize == _destinationLocalSize &&
      value.axisScale == _destinationAxisScale &&
      MatrixUtils.matrixEquals(value.transform, _destinationTransform);

  void _notifyEndpointChanged() {
    _revision += 1;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
