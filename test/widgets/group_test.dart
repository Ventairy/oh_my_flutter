import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  testWidgets('when members have separate parents, it should measure their combined translated bounds', (tester) async {
    final link = GroupLink();
    final reference = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            key: reference,
            width: 100,
            height: 100,
            child: Stack(
              children: [
                Positioned(
                  left: 10,
                  top: 20,
                  child: Group(link: link, child: const SizedBox(width: 20, height: 30)),
                ),
                Positioned(
                  left: 60,
                  top: 70,
                  child: Group(link: link, child: const SizedBox(width: 10, height: 10)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(link.measure(relativeTo: reference.currentContext!), const Rect.fromLTRB(10, 20, 70, 80));
  });

  testWidgets('when a member changes links, it should unregister from the previous group', (tester) async {
    final first = GroupLink();
    final second = GroupLink();
    final key = GlobalKey();
    Widget build(GroupLink link) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          key: key,
          width: 20,
          height: 20,
          child: Group(link: link, child: const SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpWidget(build(first));
    await tester.pumpWidget(build(second));
    expect(first.measure(relativeTo: key.currentContext!), isNull);
  });

  for (final higher in [false, true]) {
    testWidgets(
      'when zIndex is ${higher ? 'higher' : 'equal'}, it should paint ${higher ? 'the higher member' : 'the later registration'} on top',
      (tester) async {
        final link = GroupLink();
        final key = GlobalKey();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: SizedBox(
                key: key,
                width: 20,
                height: 20,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Group(
                      link: link,
                      zIndex: higher ? 2 : 0,
                      child: const ColoredBox(color: Color(0xffff0000)),
                    ),
                    Group(
                      link: link,
                      child: const ColoredBox(color: Color(0xff0000ff)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final snapshot = await link.capture(relativeTo: key.currentContext!, pixelRatio: 1);
        final image = await tester.runAsync(() => snapshot!.toImage());
        final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
        expect(bytes!.buffer.asUint8List().take(4), higher ? [255, 0, 0, 255] : [0, 0, 255, 255]);
        image!.dispose();
        snapshot!.dispose();
      },
    );
  }

  testWidgets('when same-link members are nested, it should capture translucent content only once', (tester) async {
    final link = GroupLink();
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            key: key,
            width: 20,
            height: 20,
            child: Group(
              link: link,
              child: Group(
                link: link,
                child: const ColoredBox(color: Color(0x80ff0000)),
              ),
            ),
          ),
        ),
      ),
    );
    final snapshot = await link.capture(relativeTo: key.currentContext!, pixelRatio: 1);
    final image = await tester.runAsync(() => snapshot!.toImage());
    final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.rawRgba));
    expect(bytes!.getUint8(3), 128);
    image!.dispose();
    snapshot!.dispose();
  });

  testWidgets('when originals unmount, it should retain the snapshot and export at the requested size', (tester) async {
    final link = GroupLink();
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            key: key,
            width: 20,
            height: 20,
            child: Group(
              link: link,
              child: const ColoredBox(color: Color(0xff00ff00)),
            ),
          ),
        ),
      ),
    );
    final snapshot = await link.capture(
      relativeTo: key.currentContext!,
      bounds: const Rect.fromLTWH(-5, -5, 30, 30),
      pixelRatio: 2,
    );
    await tester.pumpWidget(const SizedBox());
    final image = await tester.runAsync(() => snapshot!.toImage());
    expect((image!.width, image.height), (60, 60));
    image.dispose();
    snapshot!.dispose();
    snapshot.dispose();
  });
}
