import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/native_selectable_text/view_readiness.dart';

void main() {
  NativeSelectableTextBenchmarkViewReadiness readiness({
    AppLifecycleState? lifecycleState = AppLifecycleState.resumed,
    Size logicalSize = const Size(360, 800),
    Size physicalSize = const Size(1080, 2400),
    double devicePixelRatio = 3,
    double refreshRate = 120,
  }) {
    return NativeSelectableTextBenchmarkViewReadiness(
      lifecycleState: lifecycleState,
      logicalSize: logicalSize,
      physicalSize: physicalSize,
      devicePixelRatio: devicePixelRatio,
      refreshRate: refreshRate,
    );
  }

  group('NativeSelectableTextBenchmarkViewReadiness', () {
    test(
      'when the application is stopped with valid metrics, '
      'it should not be ready',
      () {
        expect(
          readiness(lifecycleState: AppLifecycleState.paused).isReady,
          isFalse,
        );
      },
    );

    test(
      'when the resumed view has zero logical size, it should not be ready',
      () {
        expect(readiness(logicalSize: Size.zero).isReady, isFalse);
      },
    );

    test(
      'when the resumed view has nonfinite physical size, '
      'it should not be ready',
      () {
        expect(
          readiness(
            physicalSize: const Size(double.infinity, 2400),
          ).isReady,
          isFalse,
        );
      },
    );

    test(
      'when the resumed view has zero pixel ratio, it should not be ready',
      () {
        expect(readiness(devicePixelRatio: 0).isReady, isFalse);
      },
    );

    test(
      'when the resumed view has nonfinite refresh rate, '
      'it should not be ready',
      () {
        expect(readiness(refreshRate: double.nan).isReady, isFalse);
      },
    );

    test(
      'when lifecycle and every view metric are valid, it should be ready',
      () {
        expect(readiness().isReady, isTrue);
      },
    );

    test(
      'when readiness fails, it should describe the observed startup state',
      () {
        final observation = readiness(
          lifecycleState: AppLifecycleState.paused,
          logicalSize: Size.zero,
        );

        expect(
          observation.diagnostic,
          allOf(
            contains('lifecycle=paused'),
            contains('logical_size=0.0x0.0'),
            contains('physical_size=1080.0x2400.0'),
            contains('device_pixel_ratio=3.0'),
            contains('refresh_rate_hz=120.0'),
          ),
        );
      },
    );
  });
}
