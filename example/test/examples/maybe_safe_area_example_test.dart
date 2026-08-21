import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter_example/examples/maybe_safe_area_example.dart';

void main() {
  testWidgets(
    'when the MaybeSafeArea example starts at an unsafe edge, '
    'it should paint below that edge',
    (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: const EdgeInsets.only(top: 40),
              ),
              child: child!,
            );
          },
          home: const Material(
            child: Align(
              alignment: Alignment.topLeft,
              child: MaybeSafeAreaExample(),
            ),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.byType(Chip)).dy,
        40,
      );
    },
  );
}
