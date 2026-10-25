import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'contour_frame_test_scene_builder.dart';

/// Records the actual application scenes submitted while a Contour starts.
class ContourInitialFrameTestBinding extends AutomatedTestWidgetsFlutterBinding {
  final _images = <ui.Image>[];
  bool _recording = false;

  /// Records subsequent application frames in a fixed logical canvas.
  void startRecording() {
    resetRecording();
    _recording = true;
  }

  /// Stops recording without discarding the submitted frames.
  void stopRecording() => _recording = false;

  /// Reads each recorded scene without composing an additional scene.
  Future<List<Uint8List>> frames(WidgetTester tester) async {
    final result = <Uint8List>[];
    for (final image in _images) {
      final bytes = await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba));
      result.add(bytes!.buffer.asUint8List());
    }
    return result;
  }

  /// Releases recorded images between test cases.
  void resetRecording() {
    _recording = false;
    for (final image in _images) {
      image.dispose();
    }
    _images.clear();
  }

  void _recordScene(ui.Scene scene) {
    if (!_recording || _images.length >= 256) return;
    _images.add(scene.toImageSync(100, 100));
  }

  @override
  ui.SceneBuilder createSceneBuilder() => ContourFrameTestSceneBuilder(
    delegate: super.createSceneBuilder(),
    onBuild: _recordScene,
  );
}
