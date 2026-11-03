import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

class _MorphSnapshotTest {
  static Widget endpoint({
    required bool destination,
    required bool matched,
    required MorphTarget parentTarget,
    required MorphTarget nestedTarget,
  }) {
    final nestedAlignment = switch ((matched, destination)) {
      (false, _) => Alignment.center,
      (true, true) => Alignment.bottomRight,
      (true, false) => Alignment.topLeft,
    };
    return Align(
      alignment: destination ? Alignment.bottomRight : Alignment.topLeft,
      child: Morph(
        key: ValueKey(destination),
        targets: [parentTarget],
        flightConfig: .auto(childSwitchAt: matched ? 0.5 : 0),
        child: SizedBox(
          width: destination ? 240 : 120,
          height: destination ? 180 : 80,
          child: MorphDescendant(
            flightBehavior: const .snapshot(),
            child: ColoredBox(
              color: Colors.blue,
              child: destination || matched
                  ? Align(
                      alignment: nestedAlignment,
                      child: Morph(
                        targets: [nestedTarget],
                        child: const ColoredBox(color: Colors.red, child: SizedBox.square(dimension: 40)),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  static Future<List<int>> readPixel(
    WidgetTester tester, {
    required GlobalKey captureKey,
    required Offset point,
  }) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final offset = (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
    final pixel = bytes!.buffer.asUint8List(bytes.offsetInBytes + offset, 4).toList();
    image.dispose();
    return pixel;
  }
}

void main() {
  for (final route in [false, true]) {
    for (final matched in [false, true]) {
      testWidgets(
        'when ${route ? 'navigating to' : 'replacing content with'} a ${matched ? 'paired' : 'standalone'} nested Morph, '
        'it should ${matched ? 'reserve it for its own flight' : 'keep it visible in the parent snapshot'}',
        (tester) async {
          final parentTarget = MorphTarget(
            tag: 'snapshot-parent',
            duration: const Duration(milliseconds: 400),
            curve: Curves.linear,
          );
          final nestedTarget = MorphTarget(tag: 'nested-marker');
          final captureKey = GlobalKey();
          final navigatorKey = GlobalKey<NavigatorState>();
          var destination = false;
          late StateSetter update;
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(400, 400);
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            RepaintBoundary(
              key: captureKey,
              child: MaterialApp(
                navigatorKey: navigatorKey,
                navigatorObservers: [MorphNavigatorObserver()],
                home: StatefulBuilder(
                  builder: (context, setState) {
                    update = setState;
                    return _MorphSnapshotTest.endpoint(
                      destination: destination,
                      matched: matched,
                      parentTarget: parentTarget,
                      nestedTarget: nestedTarget,
                    );
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (route) {
            navigatorKey.currentState!.push<void>(
              PageRouteBuilder<void>(
                opaque: false,
                transitionDuration: const Duration(milliseconds: 400),
                pageBuilder: (context, animation, secondaryAnimation) => _MorphSnapshotTest.endpoint(
                  destination: true,
                  matched: matched,
                  parentTarget: parentTarget,
                  nestedTarget: nestedTarget,
                ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) => child,
              ),
            );
          } else {
            update(() => destination = true);
          }
          await tester.pump();
          await tester.pump();
          await tester.pump(Duration(milliseconds: matched ? 100 : 200));
          final pixel = await tester.runAsync(
            () => _MorphSnapshotTest.readPixel(
              tester,
              captureKey: captureKey,
              point: matched ? const Offset(70, 80) : const Offset(200, 200),
            ),
          );
          await tester.pumpAndSettle();
          expect(pixel, matched ? [33, 150, 243, 255] : [244, 67, 54, 255]);
        },
      );
    }
  }
}
