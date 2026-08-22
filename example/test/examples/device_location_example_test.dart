import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter_example/examples/device_location_example.dart';

void main() {
  testWidgets(
    'when automatic coordinates succeed, it should display the coordinates',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceLocationExample(
              getCoordinates: ({prompt = true}) async {
                return const DeviceLocationCoordinates(
                  latitude: -23.556391,
                  longitude: -46.844076,
                  accuracy: 8.5,
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Use current location'));
      await tester.pump();

      expect(find.text('-23.556391, -46.844076 (±8.5 m)'), findsOneWidget);
    },
  );

  testWidgets(
    'when permission is requested, it should display the resulting status',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceLocationExample(
              requestPermission: () async {
                return DeviceLocationPermissionStatus.whileInUse;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Request permission'));
      await tester.pump();

      expect(
        find.text('Permission: whileInUse'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'when settings navigation succeeds, it should display that outcome',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceLocationExample(
              openLocationSettings: () async => true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open app settings'));
      await tester.pump();

      expect(find.text('Application settings opened.'), findsOneWidget);
    },
  );
}
