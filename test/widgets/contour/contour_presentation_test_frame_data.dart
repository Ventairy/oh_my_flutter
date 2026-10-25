import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

class ContourPresentationTestFrameData extends Fake implements ui.FrameData {
  new(this.frameNumber);

  @override
  final int frameNumber;
}
