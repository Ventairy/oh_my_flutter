import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

class DisintegrateTestHarness {
  new(
    this.tester, {
    this.native = false,
    this.nativeReady = true,
    this.readinessProbe = false,
    this.nativeGaussian = false,
    this.managedGaussianAvailable = true,
    this.acknowledgeFullDensityGaussian = true,
  }) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'prepareRenderer':
          return nativeReady;
        case 'supportsManagedGaussian':
          return managedGaussianAvailable;
        case 'prepare':
          if (!native) throw PlatformException(code: 'unavailable');
          final arguments = call.arguments as Map<Object?, Object?>;
          if (arguments['nativeGaussian'] == true) {
            if (!nativeGaussian) throw PlatformException(code: 'prepare_failed');
            final legacy = arguments['legacyGaussian'] == true;
            final hasProbe = defaultTargetPlatform == TargetPlatform.android && !legacy;
            return {
              'textureId': 7,
              'handle': ++_handle,
              'nativeGaussian': true,
              if (legacy) 'legacyGaussian': true,
              if (acknowledgeFullDensityGaussian && arguments['fullDensityGaussian'] == true)
                'fullDensityGaussian': true,
              'textureWidth': arguments['viewportWidth'],
              'textureHeight': (arguments['viewportHeight']! as int) + (hasProbe ? 1 : 0),
              if (hasProbe) ...{'probeWidth': 22, 'contentTop': 1},
            };
          }
          return {
            'textureId': 7,
            'handle': ++_handle,
            if (readinessProbe) ...{'probeWidth': 22, 'textureWidth': 120, 'textureHeight': 81, 'contentTop': 1},
          };
        case 'awaitFirstFrame':
          return await firstFrame?.future;
        case 'play':
          return await playing.future;
        case 'dispose':
        case 'releaseRenderer':
        case 'setFrame':
        case 'pause':
          return null;
      }
      throw MissingPluginException(call.method);
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });
  }

  static const channel = MethodChannel('dev.ventairy.oh_my_flutter.motion');
  final WidgetTester tester;
  final bool native;
  final bool nativeReady;
  final bool readinessProbe;
  final bool nativeGaussian;
  final bool managedGaussianAvailable;
  final bool acknowledgeFullDensityGaussian;
  final calls = <MethodCall>[];
  final motionController = MotionController();
  final GlobalKey captureKey = GlobalKey();
  final playing = Completer<Object?>();
  Completer<Object?>? firstFrame;
  int _handle = 0;

  Future<void> mount({
    required MotionEffect effect,
    List<MotionEffect>? effects,
    bool overlay = false,
    Widget? child,
    bool reducedMotion = false,
    Size canvasSize = const Size(240, 180),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: Center(
            child: RepaintBoundary(
              key: captureKey,
              child: SizedBox(
                width: canvasSize.width,
                height: canvasSize.height,
                child: Center(
                  child: Motion.list(
                    controller: motionController,
                    startup: .hold,
                    interactive: true,
                    renderPresentation: overlay ? .overlay : .replace,
                    effects: effects ?? [effect],
                    child:
                        child ??
                        ColoredBox(
                          color: ThemeData.light().colorScheme.primary,
                          child: const SizedBox(width: 120, height: 80),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> start() async {
    motionController.play();
    await prepare();
  }

  Future<void> prepare() async {
    for (var frame = 0; frame < 15; frame++) {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2)));
    }
    await tester.pump();
  }

  Future<Uint8List> pixels({double pixelRatio = 1}) async {
    final boundary = captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final result = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    return result!;
  }
}
