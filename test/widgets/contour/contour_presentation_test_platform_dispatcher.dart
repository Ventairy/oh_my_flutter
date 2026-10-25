import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'contour_presentation_test_frame_data.dart';

class ContourPresentationTestPlatformDispatcher extends TestPlatformDispatcher {
  new(this._original) : super(platformDispatcher: _original);

  final TestPlatformDispatcher _original;
  int frameNumber = 0;

  // Keep the real test view objects so DPR setters and RenderView share state.
  @override
  Iterable<TestFlutterView> get views => _original.views;

  @override
  TestFlutterView? get implicitView => _original.implicitView;

  @override
  ui.FrameData get frameData => ContourPresentationTestFrameData(frameNumber);
}
