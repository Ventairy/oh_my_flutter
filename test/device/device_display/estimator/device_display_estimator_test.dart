import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/device/device_display/estimator/device_display_estimator.dart';

void main() {
  group('DeviceDisplayEstimator', () {
    test(
      'when orientation features are built, it should derive them from the full display',
      () {
        final runtimeSource = File(
          'lib/src/device/device_display/estimator/device_display_estimator.dart',
        ).readAsStringSync();

        expect(
          <Object?>[
            RegExp(
              r'metrics\.displaySize\.width > metrics\.displaySize\.height',
            ).allMatches(runtimeSource).length,
            runtimeSource.contains(
              'metrics.viewSize.width > metrics.viewSize.height',
            ),
          ],
          <Object?>[1, false],
        );
      },
    );

    test(
      'when iOS lacks Flutter gesture and cutout evidence, it should align runtime missing features with training',
      () {
        final runtimeSource = File(
          'lib/src/device/device_display/estimator/device_display_estimator.dart',
        ).readAsStringSync();
        final trainingSource = File(
          'tool/device_display_model/src/device_display_model_models.dart',
        ).readAsStringSync();

        expect(
          <bool>[
            RegExp(
              r"'displayCutoutMissing',\s*\]",
            ).hasMatch(trainingSource),
            RegExp(
              r'2 \* _maximumEdge\(isIos \? EdgeInsets\.zero : '
              r'metrics\.systemGestureInsets\)',
            ).hasMatch(runtimeSource),
            runtimeSource.contains(
              '(isIos ? 0.0 : metrics.displayCutoutCount / 4).clamp(0, 1)',
            ),
            RegExp(
              r'if \(isIos\) 1\.0 else 0\.0,\s*'
              r'if \(isIos\) 1\.0 else 0\.0,\s*\]',
            ).hasMatch(runtimeSource),
          ],
          <bool>[true, true, true, true],
        );
      },
    );

    test('when metrics are unchanged, it should be deterministic', () {
      const metrics = DeviceDisplayMetrics(
        platformKind: DeviceDisplayPlatformKind.android,
        displaySize: Size(400, 880),
        viewSize: Size(400, 880),
        devicePixelRatio: 3,
        viewPadding: EdgeInsets.only(top: 30, bottom: 20),
      );

      expect(
        DeviceDisplayEstimator.estimate(metrics),
        DeviceDisplayEstimator.estimate(metrics),
      );
    });

    test(
      'when committed corpus fixtures are estimated, it should apply the regenerated platform pipelines',
      () {
        const android = DeviceDisplayMetrics(
          platformKind: DeviceDisplayPlatformKind.android,
          displaySize: Size(360, 800),
          viewSize: Size(360, 800),
          devicePixelRatio: 3,
          viewPadding: EdgeInsets.fromLTRB(0, 88 / 3, 0, 48),
          systemGestureInsets: EdgeInsets.fromLTRB(0, 124 / 3, 0, 48),
        );
        const ios = DeviceDisplayMetrics(
          platformKind: DeviceDisplayPlatformKind.ios,
          displaySize: Size(375, 812),
          viewSize: Size(375, 812),
          devicePixelRatio: 3,
          viewPadding: EdgeInsets.fromLTRB(0, 44, 0, 34),
        );
        final androidRadius = DeviceDisplayEstimator.estimate(android)!;
        final iosRadius = DeviceDisplayEstimator.estimate(ios)!;

        expect(
          <double>[
            androidRadius.topLeft.x,
            androidRadius.topRight.x,
            androidRadius.bottomLeft.x,
            androidRadius.bottomRight.x,
            iosRadius.topLeft.x,
            iosRadius.topRight.x,
            iosRadius.bottomLeft.x,
            iosRadius.bottomRight.x,
          ],
          <Matcher>[
            for (var index = 0; index < 4; index += 1) closeTo(33, 0.000001),
            for (var index = 0; index < 4; index += 1) closeTo(40.99557365055384, 0.000001),
          ],
        );
      },
    );

    test('when iOS padding differs by edge, it should use one symmetric radius', () {
      const metrics = DeviceDisplayMetrics(
        platformKind: DeviceDisplayPlatformKind.ios,
        displaySize: Size(402, 874),
        viewSize: Size(402, 874),
        devicePixelRatio: 3,
        viewPadding: EdgeInsets.only(top: 62, bottom: 34),
      );
      final radius = DeviceDisplayEstimator.estimate(metrics)!;

      expect(
        <double>[
          radius.topRight.x,
          radius.bottomRight.x,
          radius.bottomLeft.x,
        ],
        everyElement(closeTo(radius.topLeft.x, 0.000001)),
      );
    });

    test('when Android is estimated, it should keep each edge pair symmetric', () {
      const metrics = DeviceDisplayMetrics(
        platformKind: DeviceDisplayPlatformKind.android,
        displaySize: Size(400, 880),
        viewSize: Size(400, 880),
        devicePixelRatio: 3,
        viewPadding: EdgeInsets.only(top: 30, bottom: 20),
      );
      final radius = DeviceDisplayEstimator.estimate(metrics)!;

      expect(
        <bool>[
          radius.topLeft == radius.topRight,
          radius.bottomLeft == radius.bottomRight,
        ],
        <bool>[true, true],
      );
    });

    test('when symmetric geometry rotates, it should preserve the estimate', () {
      const portrait = DeviceDisplayMetrics(
        platformKind: DeviceDisplayPlatformKind.android,
        displaySize: Size(400, 880),
        viewSize: Size(400, 880),
        devicePixelRatio: 3,
        viewPadding: EdgeInsets.all(24),
      );
      const landscape = DeviceDisplayMetrics(
        platformKind: DeviceDisplayPlatformKind.android,
        displaySize: Size(880, 400),
        viewSize: Size(880, 400),
        devicePixelRatio: 3,
        viewPadding: EdgeInsets.all(24),
      );

      final portraitRadius = DeviceDisplayEstimator.estimate(portrait)!;
      final landscapeRadius = DeviceDisplayEstimator.estimate(landscape)!;

      expect(
        <double>[
          landscapeRadius.topLeft.x,
          landscapeRadius.bottomLeft.x,
          landscapeRadius.topRight.x,
          landscapeRadius.bottomRight.x,
        ],
        <Matcher>[
          closeTo(portraitRadius.topLeft.x, 0.000001),
          closeTo(portraitRadius.topRight.x, 0.000001),
          closeTo(portraitRadius.bottomLeft.x, 0.000001),
          closeTo(portraitRadius.bottomRight.x, 0.000001),
        ],
      );
    });

    test(
      'when iOS rotates in either landscape direction, it should preserve its symmetric estimate',
      () {
        const portrait = DeviceDisplayMetrics(
          platformKind: DeviceDisplayPlatformKind.ios,
          displaySize: Size(375, 812),
          viewSize: Size(375, 812),
          devicePixelRatio: 3,
          viewPadding: EdgeInsets.only(top: 44, bottom: 34),
        );
        const clockwise = DeviceDisplayMetrics(
          platformKind: DeviceDisplayPlatformKind.ios,
          displaySize: Size(812, 375),
          viewSize: Size(812, 375),
          devicePixelRatio: 3,
          viewPadding: EdgeInsets.only(left: 44, right: 34),
        );
        const counterClockwise = DeviceDisplayMetrics(
          platformKind: DeviceDisplayPlatformKind.ios,
          displaySize: Size(812, 375),
          viewSize: Size(812, 375),
          devicePixelRatio: 3,
          viewPadding: EdgeInsets.only(left: 34, right: 44),
        );
        final portraitRadius = DeviceDisplayEstimator.estimate(portrait)!;
        final clockwiseRadius = DeviceDisplayEstimator.estimate(clockwise)!;
        final counterClockwiseRadius = DeviceDisplayEstimator.estimate(
          counterClockwise,
        )!;

        expect(
          <double>[
            clockwiseRadius.topLeft.x,
            clockwiseRadius.topRight.x,
            clockwiseRadius.bottomLeft.x,
            clockwiseRadius.bottomRight.x,
            counterClockwiseRadius.topLeft.x,
            counterClockwiseRadius.topRight.x,
            counterClockwiseRadius.bottomLeft.x,
            counterClockwiseRadius.bottomRight.x,
          ],
          everyElement(closeTo(portraitRadius.topLeft.x, 0.000001)),
        );
      },
    );

    test(
      'when a portrait display has a landscape viewport, it should keep the display orientation',
      () {
        const landscapeViewport = DeviceDisplayMetrics(
          platformKind: DeviceDisplayPlatformKind.android,
          displaySize: Size(400, 800),
          viewSize: Size(400, 200),
          devicePixelRatio: 2,
          viewPadding: EdgeInsets.only(top: 40, bottom: 10),
        );
        const portraitViewport = DeviceDisplayMetrics(
          platformKind: DeviceDisplayPlatformKind.android,
          displaySize: Size(400, 800),
          viewSize: Size(200, 400),
          devicePixelRatio: 2,
          viewPadding: EdgeInsets.only(top: 40, bottom: 10),
        );
        final landscapeRadius = DeviceDisplayEstimator.estimate(
          landscapeViewport,
        )!;
        final portraitRadius = DeviceDisplayEstimator.estimate(
          portraitViewport,
        )!;

        expect(
          <double>[
            landscapeRadius.topLeft.x,
            landscapeRadius.topRight.x,
            landscapeRadius.bottomLeft.x,
            landscapeRadius.bottomRight.x,
          ],
          <Matcher>[
            closeTo(portraitRadius.topLeft.x, 0.000001),
            closeTo(portraitRadius.topRight.x, 0.000001),
            closeTo(portraitRadius.bottomLeft.x, 0.000001),
            closeTo(portraitRadius.bottomRight.x, 0.000001),
          ],
        );
      },
    );

    test('when Android rotates to landscape, it should map natural edges to side pairs', () {
      const portrait = DeviceDisplayMetrics(
        platformKind: DeviceDisplayPlatformKind.android,
        displaySize: Size(200, 400),
        viewSize: Size(200, 400),
        devicePixelRatio: 2,
        viewPadding: EdgeInsets.only(top: 40, bottom: 10),
        displayCutoutBounds: Rect.fromLTWH(80, 0, 40, 30),
        displayCutoutCount: 1,
      );
      const landscape = DeviceDisplayMetrics(
        platformKind: DeviceDisplayPlatformKind.android,
        displaySize: Size(400, 200),
        viewSize: Size(400, 200),
        devicePixelRatio: 2,
        viewPadding: EdgeInsets.only(left: 40, right: 10),
        displayCutoutBounds: Rect.fromLTWH(0, 80, 30, 40),
        displayCutoutCount: 1,
      );
      final portraitRadius = DeviceDisplayEstimator.estimate(portrait)!;
      final landscapeRadius = DeviceDisplayEstimator.estimate(landscape)!;

      expect(
        <double>[
          landscapeRadius.topLeft.x,
          landscapeRadius.bottomLeft.x,
          landscapeRadius.topRight.x,
          landscapeRadius.bottomRight.x,
        ],
        <Matcher>[
          closeTo(portraitRadius.topLeft.x, 0.000001),
          closeTo(portraitRadius.topRight.x, 0.000001),
          closeTo(portraitRadius.bottomLeft.x, 0.000001),
          closeTo(portraitRadius.bottomRight.x, 0.000001),
        ],
      );
    });

    test('when geometry is outside support, it should blend to the training prior', () {
      const outside = DeviceDisplayMetrics(
        platformKind: DeviceDisplayPlatformKind.android,
        displaySize: Size(400, 880),
        viewSize: Size(400, 880),
        devicePixelRatio: 2,
        viewPadding: EdgeInsets.only(top: 200),
      );
      const fartherOutside = DeviceDisplayMetrics(
        platformKind: DeviceDisplayPlatformKind.android,
        displaySize: Size(400, 880),
        viewSize: Size(400, 880),
        devicePixelRatio: 2,
        viewPadding: EdgeInsets.only(top: 1000),
      );
      final outsideRadius = DeviceDisplayEstimator.estimate(outside)!;
      final fartherOutsideRadius = DeviceDisplayEstimator.estimate(fartherOutside)!;

      expect(
        <double>[
          fartherOutsideRadius.topLeft.x,
          fartherOutsideRadius.topRight.x,
          fartherOutsideRadius.bottomLeft.x,
          fartherOutsideRadius.bottomRight.x,
        ],
        <Matcher>[
          closeTo(outsideRadius.topLeft.x, 0.000001),
          closeTo(outsideRadius.topRight.x, 0.000001),
          closeTo(outsideRadius.bottomLeft.x, 0.000001),
          closeTo(outsideRadius.bottomRight.x, 0.000001),
        ],
      );
    });

    test('when evidence is extreme, it should remain bounded by half the short side', () {
      const metrics = DeviceDisplayMetrics(
        platformKind: DeviceDisplayPlatformKind.android,
        displaySize: Size(400, 880),
        viewSize: Size(400, 880),
        devicePixelRatio: 3,
        viewPadding: EdgeInsets.only(top: 10000),
      );

      expect(
        DeviceDisplayEstimator.estimate(metrics)!.topLeft.x,
        inInclusiveRange(0, 200),
      );
    });

    test(
      'when valid iOS phone geometry is beyond training support, it should stay finite bounded and symmetric',
      () {
        const metrics = DeviceDisplayMetrics(
          platformKind: DeviceDisplayPlatformKind.ios,
          displaySize: Size(580, 1600),
          viewSize: Size(580, 1600),
          devicePixelRatio: 7.5,
          viewPadding: EdgeInsets.only(top: 180, bottom: 40),
        );
        final radius = DeviceDisplayEstimator.estimate(metrics)!;

        expect(
          <double>[
            radius.topLeft.x,
            radius.topRight.x,
            radius.bottomLeft.x,
            radius.bottomRight.x,
          ],
          everyElement(
            allOf(
              predicate<double>((value) => value.isFinite, 'is finite'),
              inInclusiveRange(0, 290),
              radius.topLeft.x,
            ),
          ),
        );
      },
    );

    test('when a metric is non-finite, it should return null', () {
      const metrics = DeviceDisplayMetrics(
        platformKind: DeviceDisplayPlatformKind.android,
        displaySize: Size(double.nan, 880),
        viewSize: Size(400, 880),
        devicePixelRatio: 3,
      );

      expect(DeviceDisplayEstimator.estimate(metrics), isNull);
    });

    test(
      'when the view is more than one physical pixel larger than the display, '
      'it should return null',
      () {
        const metrics = DeviceDisplayMetrics(
          platformKind: DeviceDisplayPlatformKind.android,
          displaySize: Size(390, 844),
          viewSize: Size(391, 844),
          devicePixelRatio: 2,
        );

        expect(DeviceDisplayEstimator.estimate(metrics), isNull);
      },
    );

    test(
      'when the view exceeds the display by one physical pixel, '
      'it should tolerate geometry rounding',
      () {
        const metrics = DeviceDisplayMetrics(
          platformKind: DeviceDisplayPlatformKind.android,
          displaySize: Size(390, 844),
          viewSize: Size(390.5, 844),
          devicePixelRatio: 2,
        );

        expect(DeviceDisplayEstimator.estimate(metrics), isNotNull);
      },
    );

    test('when the display has a fold or hinge, it should return null', () {
      const metrics = DeviceDisplayMetrics(
        platformKind: DeviceDisplayPlatformKind.android,
        displaySize: Size(800, 900),
        viewSize: Size(800, 900),
        devicePixelRatio: 2,
        hasFoldOrHinge: true,
      );

      expect(DeviceDisplayEstimator.estimate(metrics), isNull);
    });
  });
}
