import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  for (final useSwitcher in [false, true]) {
    testWidgets(
      'when a local endpoint is replaced ${useSwitcher ? 'inside a zero-duration switcher' : 'directly'}, '
      'it should paint the visual on every handoff frame',
      (tester) async {
        final boundaryKey = GlobalKey();
        final replaced = ValueNotifier<bool>(false);
        addTearDown(replaced.dispose);
        final target = MorphTarget(tag: 'replacement', duration: const Duration(milliseconds: 600));
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              navigatorObservers: [MorphNavigatorObserver()],
              home: Scaffold(
                backgroundColor: Colors.white,
                body: ValueListenableBuilder<bool>(
                  valueListenable: replaced,
                  builder: (context, showDestination, _) {
                    final child = Align(
                      key: ValueKey(showDestination),
                      alignment: showDestination ? const Alignment(-0.3, 0.2) : Alignment.center,
                      child: Morph(
                        key: ValueKey('endpoint-$showDestination'),
                        targets: [target],
                        child: SizedBox.square(
                          dimension: showDestination ? 32 : 110,
                          child: const ColoredBox(color: Colors.red),
                        ),
                      ),
                    );
                    return useSwitcher ? AnimatedSwitcher(duration: Duration.zero, child: child) : child;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        replaced.value = true;
        final framePixels = <int>[];
        for (var frame = 0; frame < 42; frame++) {
          // Capture the submitted frame before Morph's post-frame reconciliation.
          late ui.Image image;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            image = (boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImageSync();
          });
          tester.binding.scheduleFrame();
          await tester.pump(const Duration(microseconds: 16667));
          final pixels = await tester.runAsync(() async {
            try {
              final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
              var redPixels = 0;
              for (var offset = 0; offset < bytes.lengthInBytes; offset += 4) {
                if (bytes.getUint8(offset) > 200 && bytes.getUint8(offset + 1) < 100) redPixels++;
              }
              return redPixels;
            } finally {
              image.dispose();
            }
          });
          framePixels.add(pixels!);
        }
        expect(
          (framePixels.first, framePixels.every((pixels) => pixels > 0)),
          (12100, true),
        );
      },
    );
  }
}
