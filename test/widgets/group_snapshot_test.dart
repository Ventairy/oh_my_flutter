import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  testWidgets('when capturing a group directly, it should include a nested Morph child', (tester) async {
    final link = GroupLink();
    final reference = GlobalKey();
    final target = MorphTarget(tag: 'standalone-capture');
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [MorphNavigatorObserver()],
        home: Center(
          child: SizedBox(
            key: reference,
            width: 20,
            height: 20,
            child: Group(
              link: link,
              child: Morph(
                target: target,
                child: const ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final snapshot = await link.capture(relativeTo: reference.currentContext!, pixelRatio: 1);
    final image = await tester.runAsync(() => snapshot!.toImage());
    final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
    expect(bytes!.buffer.asUint8List().take(4), [255, 255, 255, 255]);
    image!.dispose();
    snapshot!.dispose();
  });

  testWidgets('when opacity is outside the group, it should capture only the child rendering', (tester) async {
    final link = GroupLink();
    final reference = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            key: reference,
            width: 20,
            height: 20,
            child: Opacity(
              opacity: .2,
              child: Group(
                link: link,
                child: const ColoredBox(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
    final snapshot = await link.capture(relativeTo: reference.currentContext!, pixelRatio: 1);
    final image = await tester.runAsync(() => snapshot!.toImage());
    final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
    expect(bytes!.getUint8(3), 255);
    image!.dispose();
    snapshot!.dispose();
  });
}
