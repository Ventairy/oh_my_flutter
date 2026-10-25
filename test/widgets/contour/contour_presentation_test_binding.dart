import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'contour_presentation_failing_scene_builder.dart';
import 'contour_presentation_test_platform_dispatcher.dart';

class ContourPresentationTestBinding extends AutomatedTestWidgetsFlutterBinding {
  bool failPictures = false;
  late final _dispatcher = ContourPresentationTestPlatformDispatcher(super.platformDispatcher);

  @override
  TestPlatformDispatcher get platformDispatcher => _dispatcher;

  @override
  void drawFrame() {
    _dispatcher.frameNumber++;
    super.drawFrame();
  }

  @override
  ui.SceneBuilder createSceneBuilder() =>
      failPictures ? ContourPresentationFailingSceneBuilder() : super.createSceneBuilder();
}
