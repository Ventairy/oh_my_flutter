import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/contour/main.dart' as benchmark;

void main() {
  testWidgets('when a result spans chunks, it should let the log transport drain between chunks', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/?enabled=false&count=1&coldFrames=1&steadyFrames=1';
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
    benchmark.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    final messages = <String>[];
    runZoned(
      () => tester.binding.platformDispatcher.onReportTimings!([
        FrameTiming(
          vsyncStart: 0,
          buildStart: 100,
          buildFinish: 200,
          rasterStart: 300,
          rasterFinish: 400,
          rasterFinishWallTime: 400,
        ),
        FrameTiming(
          vsyncStart: 17000,
          buildStart: 17100,
          buildFinish: 17200,
          rasterStart: 17300,
          rasterFinish: 17400,
          rasterFinishWallTime: 17400,
        ),
      ]),
      zoneSpecification: ZoneSpecification(print: (_, _, _, message) => messages.add(message)),
    );
    final immediate = messages.where((message) => message.startsWith('CONTOUR_BENCHMARK_CHUNK ')).length;
    await tester.pump(const Duration(milliseconds: 7));
    final beforeDrain = messages.where((message) => message.startsWith('CONTOUR_BENCHMARK_CHUNK ')).length;
    await tester.pump(const Duration(milliseconds: 1));
    final afterDrain = messages.where((message) => message.startsWith('CONTOUR_BENCHMARK_CHUNK ')).length;
    await tester.pump(const Duration(seconds: 1));
    final ended = messages.contains('CONTOUR_BENCHMARK_END');
    await tester.pumpWidget(const SizedBox.shrink());

    expect(
      <String, Object>{'immediate': immediate, 'before_drain': beforeDrain, 'after_drain': afterDrain, 'ended': ended},
      <String, Object>{'immediate': 1, 'before_drain': 1, 'after_drain': 2, 'ended': true},
    );
  });
}
