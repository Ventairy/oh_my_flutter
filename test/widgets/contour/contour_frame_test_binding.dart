import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contour_frame_test_scene_builder.dart';

/// Captures the scene that an application frame first submits to the engine.
class ContourFrameTestBinding extends AutomatedTestWidgetsFlutterBinding {
  bool _captureNext = false;
  ui.Image? _image;
  Size _captureSize = const Size.square(100);

  /// Records the next application frame at [size] without rebuilding its scene.
  void captureNextFrame({Size size = const Size.square(100)}) {
    _captureNext = true;
    _captureSize = size;
    scheduleFrame();
  }

  /// Reads the captured frame's premultiplied RGBA pixels.
  Future<Uint8List> pixels(WidgetTester tester) async {
    final bytes = await tester.runAsync(() => _image!.toByteData(format: ui.ImageByteFormat.rawRgba));
    return bytes!.buffer.asUint8List();
  }

  /// Releases the captured frame and cancels an outstanding capture request.
  void resetCapture() {
    _image?.dispose();
    _image = null;
    _captureNext = false;
    _captureSize = const Size.square(100);
  }

  void _captureScene(ui.Scene scene) {
    if (!_captureNext) return;
    _captureNext = false;
    _image?.dispose();
    _image = scene.toImageSync(_captureSize.width.toInt(), _captureSize.height.toInt());
  }

  @override
  ui.SceneBuilder createSceneBuilder() => ContourFrameTestSceneBuilder(
    delegate: super.createSceneBuilder(),
    onBuild: _captureScene,
  );
}
