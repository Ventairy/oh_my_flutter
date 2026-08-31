import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter_example/examples/device_display_example.dart';

void main() {
  testWidgets(
    'when estimation is allowed, it should display the returned logical radii',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceDisplayExample(
              cornerRadii: (_, {required estimate}) async {
                if (!estimate) return null;
                return const BorderRadius.only(
                  topLeft: Radius.circular(42),
                  topRight: Radius.circular(40),
                  bottomRight: Radius.circular(38),
                  bottomLeft: Radius.circular(36),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Allow estimate'));
      await tester.pump();

      expect(
        find.text(
          'Top-left 42.0, top-right 40.0, bottom-right 38.0, '
          'bottom-left 36.0 logical pixels.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'when exact corner data is unavailable, it should display that outcome',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceDisplayExample(
              cornerRadii: (_, {required estimate}) async => null,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Read exact data'));
      await tester.pump();

      expect(
        find.text('Display corner radii are unavailable.'),
        findsOneWidget,
      );
    },
  );
}
