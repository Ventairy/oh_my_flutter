import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  group('Morph golden', () {
    testWidgets(
      'when a card transfer reaches its midpoint, it should match the reference',
      (tester) async {
        final update = await _MorphGoldenHarness.pump(tester);
        update(value: true);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));

        await expectLater(
          find.byType(Overlay).first,
          matchesGoldenFile('screens/morph_midpoint.png'),
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'when a card transfer settles, it should match the destination reference',
      (tester) async {
        final update = await _MorphGoldenHarness.pump(tester);
        update(value: true);
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(Overlay).first,
          matchesGoldenFile('screens/morph_settled.png'),
        );
      },
    );
  });
}

class _MorphGoldenHarness {
  const _MorphGoldenHarness._();

  static Future<void Function({required bool value})> pump(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var expanded = false;
    late StateSetter setState;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: const ValueKey('golden-boundary'),
          child: ColoredBox(
            color: const Color(0xFFF1F2F4),
            child: StatefulBuilder(
              builder: (context, update) {
                setState = update;
                return Align(
                  alignment: expanded ? Alignment.bottomRight : Alignment.topLeft,
                  child: Morph(
                    tag: 'golden-container',
                    child: Container(
                      width: expanded ? 310 : 190,
                      padding: EdgeInsets.all(expanded ? 28 : 14),
                      decoration: BoxDecoration(
                        color: expanded ? const Color(0xFF3057D5) : const Color(0xFFFF4A4B),
                        borderRadius: BorderRadius.circular(expanded ? 36 : 18),
                      ),
                      child: Text(
                        expanded ? 'Shared elements without application setup.' : 'Tap to expand',
                        key: const ValueKey('description'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: expanded ? 24 : 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    void update({required bool value}) {
      setState(() => expanded = value);
    }

    return update;
  }
}
