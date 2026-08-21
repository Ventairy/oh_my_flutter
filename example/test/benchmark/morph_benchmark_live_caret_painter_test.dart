import 'package:flutter/animation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/morph/morph_benchmark_live_caret_painter.dart';

void main() {
  test(
    'when the animation is retained, it should not replace the paint delegate',
    () {
      const animation = AlwaysStoppedAnimation<double>(0.5);
      final previous = MorphBenchmarkLiveCaretPainter(animation);
      final current = MorphBenchmarkLiveCaretPainter(animation);

      expect(current.shouldRepaint(previous), isFalse);
    },
  );
}
