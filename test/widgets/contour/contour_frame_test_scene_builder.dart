import 'dart:typed_data';
import 'dart:ui' as ui;

/// Observes a completed application scene without composing a second scene.
class ContourFrameTestSceneBuilder implements ui.SceneBuilder {
  /// Invokes the supplied callback after delegated scene construction.
  new({required this._delegate, required this._onBuild});

  final ui.SceneBuilder _delegate;
  final void Function(ui.Scene) _onBuild;

  @override
  ui.TransformEngineLayer pushTransform(Float64List matrix4, {ui.TransformEngineLayer? oldLayer}) =>
      _delegate.pushTransform(matrix4, oldLayer: oldLayer);

  @override
  ui.OffsetEngineLayer pushOffset(double dx, double dy, {ui.OffsetEngineLayer? oldLayer}) =>
      _delegate.pushOffset(dx, dy, oldLayer: oldLayer);

  @override
  void addRetained(ui.EngineLayer layer) => _delegate.addRetained(layer);

  @override
  void addPicture(ui.Offset offset, ui.Picture picture, {bool isComplexHint = false, bool willChangeHint = false}) =>
      _delegate.addPicture(offset, picture, isComplexHint: isComplexHint, willChangeHint: willChangeHint);

  @override
  void pop() => _delegate.pop();

  @override
  ui.Scene build() {
    final scene = _delegate.build();
    _onBuild(scene);
    return scene;
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected SceneBuilder call: ${invocation.memberName}');
}
