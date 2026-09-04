import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/device/device_display/device_display_platform.dart';
import 'package:oh_my_flutter/src/device/device_display/device_display_platform_corner_radii.dart';

part '_fake_device_display_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceDisplay', () {
    late DeviceDisplayPlatform originalPlatform;
    late _FakeDeviceDisplayPlatform platform;

    setUp(() {
      originalPlatform = DeviceDisplayPlatform.instance;
      platform = _FakeDeviceDisplayPlatform();
      DeviceDisplayPlatform.instance = platform;
    });

    tearDown(() {
      DeviceDisplayPlatform.instance = originalPlatform;
      debugDefaultTargetPlatformOverride = null;
    });

    Future<BorderRadius?> readCornerRadii(
      WidgetTester tester, {
      MediaQueryData? mediaQueryData,
      TargetPlatform targetPlatform = TargetPlatform.android,
    }) async {
      late BuildContext context;
      final child = Builder(
        builder: (builderContext) {
          context = builderContext;
          return const SizedBox.shrink();
        },
      );

      await tester.pumpWidget(
        mediaQueryData == null ? child : MediaQuery(data: mediaQueryData, child: child),
      );
      debugDefaultTargetPlatformOverride = targetPlatform;
      try {
        return await const DeviceDisplay().cornerRadii(context);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }

    void configureView(
      WidgetTester tester, {
      Size physicalSize = const Size(780, 1688),
      double devicePixelRatio = 2,
    }) {
      tester.view
        ..physicalSize = physicalSize
        ..devicePixelRatio = devicePixelRatio;
      tester.view.display.size = physicalSize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.display.resetSize);
    }

    testWidgets(
      'when MediaQuery provides radii, it should return the Flutter value',
      (tester) async {
        const radii = BorderRadius.only(
          topLeft: Radius.circular(41),
          topRight: Radius.circular(42),
          bottomRight: Radius.circular(43),
          bottomLeft: Radius.circular(44),
        );

        final result = await readCornerRadii(
          tester,
          mediaQueryData: const MediaQueryData(displayCornerRadii: radii),
        );

        expect((result, platform.requests), (radii, 0));
      },
    );

    testWidgets(
      'when MediaQuery provides zero radii, it should preserve the Flutter value',
      (tester) async {
        final result = await readCornerRadii(
          tester,
          mediaQueryData: const MediaQueryData(
            displayCornerRadii: BorderRadius.zero,
          ),
        );

        expect((result, platform.requests), (BorderRadius.zero, 0));
      },
    );

    testWidgets(
      'when the Flutter view provides radii, it should convert them to logical pixels',
      (tester) async {
        configureView(tester);
        final view = _CornerRadiiTestFlutterView(
          tester.view,
          cornerRadii: const ui.DisplayCornerRadii(
            topLeft: 80,
            topRight: 82,
            bottomRight: 84,
            bottomLeft: 86,
          ),
        );
        late BuildContext context;
        await tester.pumpWidget(
          RawView(
            view: view,
            child: Builder(
              builder: (builderContext) {
                context = builderContext;
                return const SizedBox.shrink();
              },
            ),
          ),
          wrapWithView: false,
        );

        final result = await const DeviceDisplay().cornerRadii(context);

        expect(
          result,
          const BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(41),
            bottomRight: Radius.circular(42),
            bottomLeft: Radius.circular(43),
          ),
        );
      },
    );

    for (final targetPlatform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets(
        'when $targetPlatform provides physical radii, it should return logical radii',
        (tester) async {
          configureView(tester);
          platform.cornerRadii = const DeviceDisplayPlatformCornerRadii(
            topLeft: 80,
            topRight: 82,
            bottomRight: 84,
            bottomLeft: 86,
          );

          final result = await readCornerRadii(
            tester,
            targetPlatform: targetPlatform,
          );

          expect(
            result,
            const BorderRadius.only(
              topLeft: Radius.circular(40),
              topRight: Radius.circular(41),
              bottomRight: Radius.circular(42),
              bottomLeft: Radius.circular(43),
            ),
          );
        },
      );
    }

    testWidgets(
      'when platform radii are requested, it should send physical Flutter geometry',
      (tester) async {
        configureView(tester);

        await readCornerRadii(tester);

        expect(platform.requestedGeometry, (780, 1688, 780, 1688));
      },
    );

    testWidgets(
      'when the platform provides zero radii, it should preserve every zero',
      (tester) async {
        configureView(tester);
        platform.cornerRadii = const DeviceDisplayPlatformCornerRadii(
          topLeft: 0,
          topRight: 0,
          bottomRight: 0,
          bottomLeft: 0,
        );

        final result = await readCornerRadii(tester);

        expect(result, BorderRadius.zero);
      },
    );

    testWidgets(
      'when the platform provides no radii, it should return null',
      (tester) async {
        configureView(tester);

        final result = await readCornerRadii(tester);

        expect(result, isNull);
      },
    );

    testWidgets(
      'when the platform request fails, it should return null',
      (tester) async {
        configureView(tester);
        platform.error = Exception('unavailable');

        final result = await readCornerRadii(tester);

        expect(result, isNull);
      },
    );

    for (final entry in <String, DeviceDisplayPlatformCornerRadii>{
      'a non-finite radius': const DeviceDisplayPlatformCornerRadii(
        topLeft: double.nan,
        topRight: 0,
        bottomRight: 0,
        bottomLeft: 0,
      ),
      'a negative radius': const DeviceDisplayPlatformCornerRadii(
        topLeft: 0,
        topRight: -1,
        bottomRight: 0,
        bottomLeft: 0,
      ),
      'a radius larger than half the display': const DeviceDisplayPlatformCornerRadii(
        topLeft: 391,
        topRight: 0,
        bottomRight: 0,
        bottomLeft: 0,
      ),
    }.entries) {
      testWidgets(
        'when the platform returns ${entry.key}, it should return null',
        (tester) async {
          configureView(tester);
          platform.cornerRadii = entry.value;

          final result = await readCornerRadii(tester);

          expect(result, isNull);
        },
      );
    }

    testWidgets(
      'when a platform value is geometrically impossible, it should retry the geometry',
      (tester) async {
        configureView(tester);
        platform.cornerRadii = const DeviceDisplayPlatformCornerRadii(
          topLeft: 391,
          topRight: 0,
          bottomRight: 0,
          bottomLeft: 0,
        );

        await readCornerRadii(tester);
        platform.cornerRadii = const DeviceDisplayPlatformCornerRadii(
          topLeft: 80,
          topRight: 80,
          bottomRight: 80,
          bottomLeft: 80,
        );
        final result = await readCornerRadii(tester);

        expect(
          (requests: platform.requests, result: result),
          (
            requests: 2,
            result: const BorderRadius.all(Radius.circular(40)),
          ),
        );
      },
    );

    testWidgets(
      'when the current platform is unsupported, it should not query the host',
      (tester) async {
        configureView(tester);

        final result = await readCornerRadii(
          tester,
          targetPlatform: TargetPlatform.macOS,
        );

        expect((result, platform.requests), (null, 0));
      },
    );

    testWidgets(
      'when the Flutter view is larger than its display, it should defer validation to the host',
      (tester) async {
        configureView(tester, physicalSize: const Size(782, 1688));
        tester.view.display.size = const Size(780, 1688);

        final result = await readCornerRadii(tester);

        expect((result, platform.requests), (null, 1));
      },
    );

    testWidgets(
      'when the Flutter view is rotated relative to its display, it should query the host',
      (tester) async {
        configureView(tester, physicalSize: const Size(1688, 780));
        tester.view.display.size = const Size(780, 1688);
        platform.cornerRadii = const DeviceDisplayPlatformCornerRadii(
          topLeft: 80,
          topRight: 80,
          bottomRight: 80,
          bottomLeft: 80,
        );

        final result = await readCornerRadii(
          tester,
          targetPlatform: TargetPlatform.iOS,
        );

        expect(result, const BorderRadius.all(Radius.circular(40)));
      },
    );

    testWidgets(
      'when the widget unmounts during a platform request, it should complete from the snapshot',
      (tester) async {
        configureView(tester);
        final completer = Completer<DeviceDisplayPlatformCornerRadii?>();
        platform.completer = completer;
        late BuildContext context;
        await tester.pumpWidget(
          Builder(
            builder: (builderContext) {
              context = builderContext;
              return const SizedBox.shrink();
            },
          ),
        );

        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final future = const DeviceDisplay().cornerRadii(context);
        debugDefaultTargetPlatformOverride = null;
        await tester.pumpWidget(const SizedBox.shrink());
        completer.complete(
          const DeviceDisplayPlatformCornerRadii(
            topLeft: 80,
            topRight: 80,
            bottomRight: 80,
            bottomLeft: 80,
          ),
        );

        expect(
          future,
          completion(const BorderRadius.all(Radius.circular(40))),
        );
      },
    );

    testWidgets(
      'when platform requests overlap for one geometry, it should query the host once',
      (tester) async {
        configureView(tester);
        final completer = Completer<DeviceDisplayPlatformCornerRadii?>();
        platform.completer = completer;
        late BuildContext context;
        await tester.pumpWidget(
          Builder(
            builder: (builderContext) {
              context = builderContext;
              return const SizedBox.shrink();
            },
          ),
        );

        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        final first = const DeviceDisplay().cornerRadii(context);
        final second = const DeviceDisplay().cornerRadii(context);
        debugDefaultTargetPlatformOverride = null;
        completer.complete(
          const DeviceDisplayPlatformCornerRadii(
            topLeft: 80,
            topRight: 80,
            bottomRight: 80,
            bottomLeft: 80,
          ),
        );
        await Future.wait([first, second]);

        expect(platform.requests, 1);
      },
    );

    testWidgets(
      'when geometry is unchanged after completion, it should reuse the platform value',
      (tester) async {
        configureView(tester);
        platform.cornerRadii = const DeviceDisplayPlatformCornerRadii(
          topLeft: 80,
          topRight: 80,
          bottomRight: 80,
          bottomLeft: 80,
        );

        await readCornerRadii(tester);
        await readCornerRadii(tester);

        expect(platform.requests, 1);
      },
    );

    testWidgets(
      'when a platform value is temporarily absent, it should retry the geometry',
      (tester) async {
        configureView(tester);

        await readCornerRadii(tester);
        platform.cornerRadii = const DeviceDisplayPlatformCornerRadii(
          topLeft: 80,
          topRight: 80,
          bottomRight: 80,
          bottomLeft: 80,
        );
        final result = await readCornerRadii(tester);

        expect(
          (requests: platform.requests, result: result),
          (
            requests: 2,
            result: const BorderRadius.all(Radius.circular(40)),
          ),
        );
      },
    );

    testWidgets(
      'when display geometry changes, it should request a fresh platform value',
      (tester) async {
        configureView(tester);
        platform.cornerRadii = const DeviceDisplayPlatformCornerRadii(
          topLeft: 80,
          topRight: 80,
          bottomRight: 80,
          bottomLeft: 80,
        );

        await readCornerRadii(tester);
        tester.view.physicalSize = const Size(800, 1700);
        tester.view.display.size = const Size(800, 1700);
        await readCornerRadii(tester);

        expect(platform.requests, 2);
      },
    );

    testWidgets(
      'when display metrics change without changing size, it should request a fresh platform value',
      (tester) async {
        configureView(tester);
        platform.cornerRadii = const DeviceDisplayPlatformCornerRadii(
          topLeft: 80,
          topRight: 80,
          bottomRight: 80,
          bottomLeft: 80,
        );

        await readCornerRadii(tester);
        tester.view.physicalSize = const Size(780, 1688);
        await readCornerRadii(tester);

        expect(platform.requests, 2);
      },
    );

    testWidgets(
      'when the target mobile platform changes, it should request that platform value',
      (tester) async {
        configureView(tester);
        platform.cornerRadii = const DeviceDisplayPlatformCornerRadii(
          topLeft: 80,
          topRight: 80,
          bottomRight: 80,
          bottomLeft: 80,
        );

        await readCornerRadii(tester);
        await readCornerRadii(tester, targetPlatform: TargetPlatform.iOS);

        expect(platform.requests, 2);
      },
    );
  });
}

final class _CornerRadiiTestFlutterView extends TestFlutterView {
  _CornerRadiiTestFlutterView(
    ui.FlutterView view, {
    required this.cornerRadii,
  }) : super(
         view: view,
         platformDispatcher: view.platformDispatcher as TestPlatformDispatcher,
         display: view.display as TestDisplay,
       );

  final ui.DisplayCornerRadii? cornerRadii;

  @override
  ui.DisplayCornerRadii? get displayCornerRadii => cornerRadii;
}
