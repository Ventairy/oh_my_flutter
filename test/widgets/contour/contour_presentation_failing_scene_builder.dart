import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

class ContourPresentationFailingSceneBuilder extends Fake implements ui.SceneBuilder {
  final ui.SceneBuilder _delegate = ui.SceneBuilder();

  @override
  ui.TransformEngineLayer pushTransform(Float64List matrix4, {ui.TransformEngineLayer? oldLayer}) =>
      _delegate.pushTransform(matrix4, oldLayer: oldLayer);

  @override
  ui.OffsetEngineLayer pushOffset(double dx, double dy, {ui.OffsetEngineLayer? oldLayer}) =>
      _delegate.pushOffset(dx, dy, oldLayer: oldLayer);

  @override
  void addRetained(ui.EngineLayer retainedLayer) => _delegate.addRetained(retainedLayer);

  @override
  void addPicture(ui.Offset offset, ui.Picture picture, {bool isComplexHint = false, bool willChangeHint = false}) {
    throw StateError('test addPicture failed before emission');
  }

  @override
  void pop() => _delegate.pop();

  @override
  ui.Scene build() => _delegate.build();
}
