import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  testWidgets('when no members are attached, it should return no capture', (tester) async {
    final reference = GlobalKey();
    await tester.pumpWidget(SizedBox(key: reference));
    expect(await GroupLink().capture(relativeTo: reference.currentContext!), isNull);
  });

  testWidgets('when a capture exceeds the pixel budget, it should return no partial snapshot', (tester) async {
    final link = GroupLink();
    final reference = GlobalKey();
    await tester.pumpWidget(
      SizedBox(
        key: reference,
        child: Group(link: link, child: const SizedBox.expand()),
      ),
    );
    expect(await link.capture(relativeTo: reference.currentContext!, pixelRatio: 100), isNull);
  });

  testWidgets('when an ancestor scales a member, it should measure in the requested coordinate frame', (tester) async {
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
            child: Align(
              alignment: Alignment.topLeft,
              child: Transform.scale(
                scale: 2,
                alignment: Alignment.topLeft,
                child: Group(link: link, child: const SizedBox(width: 20, height: 30)),
              ),
            ),
          ),
        ),
      ),
    );
    expect(link.measure(relativeTo: reference.currentContext!), const Rect.fromLTWH(0, 0, 40, 60));
  });
}
