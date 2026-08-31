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
    });

    Future<BorderRadius?> readCornerRadii(
      WidgetTester tester, {
      MediaQueryData? mediaQueryData,
      bool estimate = false,
      TargetPlatform? targetPlatform,
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
      late final Future<BorderRadius?> future;
      debugDefaultTargetPlatformOverride = targetPlatform;
      try {
        future = const DeviceDisplay().cornerRadii(
          context,
          estimate: estimate,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      return future;
    }

    void configurePhoneView(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(780, 1688)
        ..devicePixelRatio = 2;
      tester.view.display.size = const Size(780, 1688);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.display.resetSize);
    }

    void configureTabletView(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(1600, 2400)
        ..devicePixelRatio = 2;
      tester.view.display.size = const Size(1600, 2400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.display.resetSize);
    }

    void configureFold(WidgetTester tester) {
      tester.view.displayFeatures = const <ui.DisplayFeature>[
        ui.DisplayFeature(
          bounds: Rect.fromLTWH(389, 0, 2, 844),
          type: ui.DisplayFeatureType.hinge,
          state: ui.DisplayFeatureState.postureFlat,
        ),
      ];
      addTearDown(tester.view.resetDisplayFeatures);
    }

    testWidgets(
      'when MediaQuery provides radii, it should return the exact value',
      (tester) async {
        const exact = BorderRadius.only(
          topLeft: Radius.circular(41),
          topRight: Radius.circular(42),
          bottomRight: Radius.circular(43),
          bottomLeft: Radius.circular(44),
        );

        final result = await readCornerRadii(
          tester,
          mediaQueryData: const MediaQueryData(
            displayCornerRadii: exact,
          ),
        );

        expect(result, exact);
      },
    );

    testWidgets(
      'when MediaQuery provides zero radii, it should preserve the exact zero',
      (tester) async {
        final result = await readCornerRadii(
          tester,
          mediaQueryData: const MediaQueryData(
            displayCornerRadii: BorderRadius.zero,
          ),
          estimate: true,
        );

        expect(result, BorderRadius.zero);
      },
    );

    testWidgets(
      'when the raw view provides radii, it should return the exact logical value',
      (tester) async {
        configurePhoneView(tester);
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

    testWidgets(
      'when the raw view provides zero radii, it should preserve the exact zero',
      (tester) async {
        configurePhoneView(tester);
        final view = _CornerRadiiTestFlutterView(
          tester.view,
          cornerRadii: const ui.DisplayCornerRadii(
            topLeft: 0,
            topRight: 0,
            bottomRight: 0,
            bottomLeft: 0,
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

        final result = await const DeviceDisplay().cornerRadii(
          context,
          estimate: true,
        );

        expect(result, BorderRadius.zero);
      },
    );

    testWidgets(
      'when MediaQuery and the raw view provide radii, '
      'it should prefer the MediaQuery value',
      (tester) async {
        configurePhoneView(tester);
        final view = _CornerRadiiTestFlutterView(
          tester.view,
          cornerRadii: const ui.DisplayCornerRadii(
            topLeft: 80,
            topRight: 80,
            bottomRight: 80,
            bottomLeft: 80,
          ),
        );
        late BuildContext context;
        await tester.pumpWidget(
          View(
            view: view,
            child: MediaQuery(
              data: const MediaQueryData(
                displayCornerRadii: BorderRadius.all(Radius.circular(20)),
              ),
              child: Builder(
                builder: (builderContext) {
                  context = builderContext;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          wrapWithView: false,
        );

        final result = await const DeviceDisplay().cornerRadii(context);

        expect(result, const BorderRadius.all(Radius.circular(20)));
      },
    );

    testWidgets(
      'when an exact value exists, it should not request Android evidence',
      (tester) async {
        await readCornerRadii(
          tester,
          mediaQueryData: const MediaQueryData(
            displayCornerRadii: BorderRadius.all(Radius.circular(32)),
          ),
          estimate: true,
          targetPlatform: TargetPlatform.android,
        );

        expect(platform.requests, 0);
      },
    );

    testWidgets(
      'when estimation is disabled, it should not request Android evidence',
      (tester) async {
        configurePhoneView(tester);

        final result = await readCornerRadii(
          tester,
          targetPlatform: TargetPlatform.android,
        );

        expect((result, platform.requests), (null, 0));
      },
    );

    testWidgets(
      'when Android provides physical radii, it should return logical radii',
      (tester) async {
        configurePhoneView(tester);
        platform.cornerRadii = const DeviceDisplayPlatformCornerRadii(
          topLeft: 80,
          topRight: 82,
          bottomRight: 84,
          bottomLeft: 86,
        );

        final result = await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.android,
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

    testWidgets(
      'when Android evidence is requested, it should send the captured physical geometry',
      (tester) async {
        configurePhoneView(tester);

        await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.android,
        );

        expect(
          platform.requestedGeometry,
          (780, 1688, 780, 1688),
        );
      },
    );

    testWidgets(
      'when Android provides tablet radii, it should return the platform value',
      (tester) async {
        configureTabletView(tester);
        platform.cornerRadii = const DeviceDisplayPlatformCornerRadii(
          topLeft: 80,
          topRight: 80,
          bottomRight: 80,
          bottomLeft: 80,
        );

        final result = await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.android,
        );

        expect(result, const BorderRadius.all(Radius.circular(40)));
      },
    );

    testWidgets(
      'when Android provides zero tablet radii, it should preserve the authoritative zero',
      (tester) async {
        configureTabletView(tester);
        platform.cornerRadii = const DeviceDisplayPlatformCornerRadii(
          topLeft: 0,
          topRight: 0,
          bottomRight: 0,
          bottomLeft: 0,
        );

        final result = await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.android,
        );

        expect(result, BorderRadius.zero);
      },
    );

    testWidgets(
      'when Android provides foldable radii, it should return the platform value',
      (tester) async {
        configurePhoneView(tester);
        configureFold(tester);
        platform.cornerRadii = const DeviceDisplayPlatformCornerRadii(
          topLeft: 80,
          topRight: 80,
          bottomRight: 80,
          bottomLeft: 80,
        );

        final result = await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.android,
        );

        expect(result, const BorderRadius.all(Radius.circular(40)));
      },
    );

    testWidgets(
      'when Android evidence fails, it should use the mathematical estimate',
      (tester) async {
        configurePhoneView(tester);
        platform.error = Exception('unavailable');

        final result = await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.android,
        );

        expect(result, isNotNull);
      },
    );

    testWidgets(
      'when estimating on iOS, it should not request a native display value',
      (tester) async {
        configurePhoneView(tester);

        final result = await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.iOS,
        );

        expect((result != null, platform.requests), (true, 0));
      },
    );

    testWidgets(
      'when estimating on iOS, it should not read Android cache identity',
      (tester) async {
        configurePhoneView(tester);
        final view = _CornerRadiiTestFlutterView(
          tester.view,
          cornerRadii: null,
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
        view.failOnViewIdRead = true;

        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final BorderRadius? result;
        try {
          result = await const DeviceDisplay().cornerRadii(
            context,
            estimate: true,
          );
        } finally {
          view.failOnViewIdRead = false;
          debugDefaultTargetPlatformOverride = null;
        }

        expect(result, isNotNull);
      },
    );

    testWidgets(
      'when MediaQuery padding is modified, it should use raw view evidence',
      (tester) async {
        configurePhoneView(tester);

        final withoutModifiedPadding = await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.iOS,
        );
        final withModifiedPadding = await readCornerRadii(
          tester,
          mediaQueryData: const MediaQueryData(
            viewPadding: EdgeInsets.all(200),
          ),
          estimate: true,
          targetPlatform: TargetPlatform.iOS,
        );

        expect(withModifiedPadding, withoutModifiedPadding);
      },
    );

    testWidgets(
      'when estimating on an iOS tablet, it should not use the phone model',
      (tester) async {
        configureTabletView(tester);

        final result = await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.iOS,
        );

        expect(result, isNull);
      },
    );

    testWidgets(
      'when estimating on an iOS foldable, it should not use the phone model',
      (tester) async {
        configurePhoneView(tester);
        configureFold(tester);

        final result = await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.iOS,
        );

        expect(result, isNull);
      },
    );

    testWidgets(
      'when estimating on an unsupported platform, it should return null',
      (tester) async {
        configurePhoneView(tester);

        final result = await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.macOS,
        );

        expect(result, isNull);
      },
    );

    testWidgets(
      'when estimating on a watch-shaped Android display, it should return null',
      (tester) async {
        tester.view
          ..physicalSize = const Size(450, 450)
          ..devicePixelRatio = 2;
        tester.view.display.size = const Size(450, 450);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.display.resetSize);

        final result = await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.android,
        );

        expect(result, isNull);
      },
    );

    testWidgets(
      'when the Flutter view is larger than its display, '
      'it should reject the inconsistent snapshot',
      (tester) async {
        tester.view
          ..physicalSize = const Size(782, 1688)
          ..devicePixelRatio = 2;
        tester.view.display.size = const Size(780, 1688);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.display.resetSize);

        final result = await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.android,
        );

        expect((result, platform.requests), (null, 0));
      },
    );

    testWidgets(
      'when Android phone geometry is outside model support, '
      'it should return a finite bounded estimate',
      (tester) async {
        tester.view
          ..physicalSize = const Size(600, 1680)
          ..devicePixelRatio = 2;
        tester.view.display.size = const Size(600, 1680);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.display.resetSize);

        final result = await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.android,
        );
        final values = <double>[
          result!.topLeft.x,
          result.topRight.x,
          result.bottomRight.x,
          result.bottomLeft.x,
        ];

        expect(
          values.every((value) => value.isFinite && value >= 0 && value <= 150),
          isTrue,
        );
      },
    );

    testWidgets(
      'when the widget unmounts during an Android request, '
      'it should complete from the captured geometry',
      (tester) async {
        configurePhoneView(tester);
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
        final Future<BorderRadius?> future;
        try {
          future = const DeviceDisplay().cornerRadii(
            context,
            estimate: true,
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
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
          completion(
            const BorderRadius.all(Radius.circular(40)),
          ),
        );
      },
    );

    testWidgets(
      'when Android requests overlap for one geometry, '
      'it should request platform evidence once',
      (tester) async {
        configurePhoneView(tester);
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
        final Future<BorderRadius?> first;
        final Future<BorderRadius?> second;
        try {
          first = const DeviceDisplay().cornerRadii(context, estimate: true);
          second = const DeviceDisplay().cornerRadii(context, estimate: true);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
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
      'when many Android keys are in flight, '
      'it should keep every pending request deduplicated',
      (tester) async {
        configurePhoneView(tester);
        final completer = Completer<DeviceDisplayPlatformCornerRadii?>();
        final platforms = List<_FakeDeviceDisplayPlatform>.generate(
          9,
          (_) => _FakeDeviceDisplayPlatform()..completer = completer,
        );
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
        final futures = <Future<BorderRadius?>>[];
        try {
          for (final candidate in platforms) {
            DeviceDisplayPlatform.instance = candidate;
            futures.add(
              const DeviceDisplay().cornerRadii(context, estimate: true),
            );
          }
          DeviceDisplayPlatform.instance = platforms.first;
          futures.add(
            const DeviceDisplay().cornerRadii(context, estimate: true),
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
        completer.complete(
          const DeviceDisplayPlatformCornerRadii(
            topLeft: 80,
            topRight: 80,
            bottomRight: 80,
            bottomLeft: 80,
          ),
        );
        await Future.wait(futures);

        expect(
          platforms.fold<int>(
            0,
            (requests, candidate) => requests + candidate.requests,
          ),
          platforms.length,
        );
      },
    );

    testWidgets(
      'when Android geometry is unchanged after completion, '
      'it should reuse the platform evidence',
      (tester) async {
        configurePhoneView(tester);
        platform.cornerRadii = const DeviceDisplayPlatformCornerRadii(
          topLeft: 80,
          topRight: 80,
          bottomRight: 80,
          bottomLeft: 80,
        );

        await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.android,
        );
        await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.android,
        );

        expect(platform.requests, 1);
      },
    );

    testWidgets(
      'when Android evidence is temporarily absent, '
      'it should retry the same geometry',
      (tester) async {
        configurePhoneView(tester);

        await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.android,
        );
        platform.cornerRadii = const DeviceDisplayPlatformCornerRadii(
          topLeft: 80,
          topRight: 80,
          bottomRight: 80,
          bottomLeft: 80,
        );
        final result = await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.android,
        );

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
      'when Android geometry changes after completion, '
      'it should invalidate the cached platform evidence',
      (tester) async {
        configurePhoneView(tester);
        platform.cornerRadii = const DeviceDisplayPlatformCornerRadii(
          topLeft: 80,
          topRight: 80,
          bottomRight: 80,
          bottomLeft: 80,
        );

        await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.android,
        );
        tester.view.physicalSize = const Size(800, 1700);
        tester.view.display.size = const Size(800, 1700);
        await readCornerRadii(
          tester,
          estimate: true,
          targetPlatform: TargetPlatform.android,
        );

        expect(platform.requests, 2);
      },
    );

    testWidgets(
      'when display geometry changes during an Android request, '
      'it should start a new platform request',
      (tester) async {
        configurePhoneView(tester);
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
        final Future<BorderRadius?> first;
        final Future<BorderRadius?> second;
        try {
          first = const DeviceDisplay().cornerRadii(context, estimate: true);
          tester.view.physicalSize = const Size(800, 1700);
          tester.view.display.size = const Size(800, 1700);
          second = const DeviceDisplay().cornerRadii(context, estimate: true);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
        completer.complete(
          const DeviceDisplayPlatformCornerRadii(
            topLeft: 80,
            topRight: 80,
            bottomRight: 80,
            bottomLeft: 80,
          ),
        );
        await Future.wait([first, second]);

        expect(platform.requests, 2);
      },
    );

    testWidgets(
      'when display orientation changes during an Android request, '
      'it should start a new platform request',
      (tester) async {
        configurePhoneView(tester);
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
        final Future<BorderRadius?> first;
        final Future<BorderRadius?> second;
        try {
          first = const DeviceDisplay().cornerRadii(context, estimate: true);
          tester.view.physicalSize = const Size(1688, 780);
          tester.view.display.size = const Size(1688, 780);
          second = const DeviceDisplay().cornerRadii(context, estimate: true);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
        completer.complete(
          const DeviceDisplayPlatformCornerRadii(
            topLeft: 80,
            topRight: 80,
            bottomRight: 80,
            bottomLeft: 80,
          ),
        );
        await Future.wait([first, second]);

        expect(platform.requests, 2);
      },
    );

    testWidgets(
      'when display metrics change without changing size, '
      'it should start a new platform request',
      (tester) async {
        configurePhoneView(tester);
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
        final Future<BorderRadius?> first;
        final Future<BorderRadius?> second;
        try {
          first = const DeviceDisplay().cornerRadii(context, estimate: true);
          tester.view.physicalSize = const Size(780, 1688);
          second = const DeviceDisplay().cornerRadii(context, estimate: true);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
        completer.complete(
          const DeviceDisplayPlatformCornerRadii(
            topLeft: 80,
            topRight: 80,
            bottomRight: 80,
            bottomLeft: 80,
          ),
        );
        await Future.wait([first, second]);

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
  bool failOnViewIdRead = false;

  @override
  ui.DisplayCornerRadii? get displayCornerRadii => cornerRadii;

  @override
  int get viewId {
    if (failOnViewIdRead) {
      throw StateError('Android cache identity was read on iOS.');
    }
    return super.viewId;
  }
}
