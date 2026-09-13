import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  const padding = EdgeInsets.fromLTRB(12, 40, 16, 20);
  Widget host(Widget child) => MediaQuery(
    data: const MediaQueryData(size: Size(800, 600), padding: padding),
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );

  for (final entry in <(String, Rect, EdgeInsets)>[
    (
      'a small partly offscreen surface',
      const Rect.fromLTWH(-10, -10, 20, 20),
      const EdgeInsets.only(left: 10, top: 10),
    ),
    ('all four edges', const Rect.fromLTWH(0, 0, 800, 600), padding),
    ('an inset surface', const Rect.fromLTWH(100, 100, 200, 200), EdgeInsets.zero),
    ('partial overlap', const Rect.fromLTWH(8, 30, 784, 560), const EdgeInsets.fromLTRB(4, 10, 8, 10)),
    ('offscreen distance', const Rect.fromLTWH(-100, -100, 1000, 800), padding),
    ('a fully offscreen surface', const Rect.fromLTWH(-100, -100, 20, 20), EdgeInsets.zero),
  ]) {
    testWidgets('when measuring ${entry.$1}, it should report local overlap', (tester) async {
      final handle = SafeAreaObserverHandle();
      addTearDown(handle.dispose);
      await tester.pumpWidget(
        host(
          Stack(
            children: [
              Positioned.fromRect(
                rect: entry.$2,
                child: SafeAreaObserver(handle: handle, child: const SizedBox.expand()),
              ),
            ],
          ),
        ),
      );
      expect(handle.avoidanceInsets, entry.$3);
    });
  }

  testWidgets('when edges are disabled, it should ignore only those edges', (tester) async {
    final handle = SafeAreaObserverHandle();
    addTearDown(handle.dispose);
    await tester.pumpWidget(
      host(SafeAreaObserver(handle: handle, left: false, bottom: false, child: const SizedBox.expand())),
    );
    expect(handle.avoidanceInsets, const EdgeInsets.only(top: 40, right: 16));
  });

  testWidgets('when scaled, it should report local logical units', (tester) async {
    final handle = SafeAreaObserverHandle();
    addTearDown(handle.dispose);
    await tester.pumpWidget(
      host(
        Align(
          alignment: Alignment.topLeft,
          child: Transform.scale(
            scale: 2,
            alignment: Alignment.topLeft,
            child: SafeAreaObserver(handle: handle, child: const SizedBox(width: 400, height: 300)),
          ),
        ),
      ),
    );
    expect(handle.avoidanceInsets, padding / 2);
  });

  testWidgets('when observing, it should preserve child geometry and MediaQuery', (tester) async {
    final handle = SafeAreaObserverHandle();
    addTearDown(handle.dispose);
    const key = ValueKey('content');
    late EdgeInsets childPadding;
    await tester.pumpWidget(
      host(
        SafeAreaObserver(
          handle: handle,
          child: Builder(
            builder: (context) {
              childPadding = MediaQuery.paddingOf(context);
              return const SizedBox.expand(key: key);
            },
          ),
        ),
      ),
    );
    expect((tester.getRect(find.byKey(key)), childPadding), (const Rect.fromLTWH(0, 0, 800, 600), padding));
  });
}
