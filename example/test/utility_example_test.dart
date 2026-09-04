import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter_example/examples/controlled_visibility_example.dart';
import 'package:oh_my_flutter_example/examples/device_display_example.dart';
import 'package:oh_my_flutter_example/examples/device_location_example.dart';
import 'package:oh_my_flutter_example/examples/marquee_example.dart';
import 'package:oh_my_flutter_example/examples/maybe_safe_area_example.dart';
import 'package:oh_my_flutter_example/examples/morph_example.dart';
import 'package:oh_my_flutter_example/examples/motion_example.dart';
import 'package:oh_my_flutter_example/examples/native_selectable_text_example.dart';
import 'package:oh_my_flutter_example/examples/relative_time_example.dart';
import 'package:oh_my_flutter_example/examples/route_settled_example.dart';
import 'package:oh_my_flutter_example/examples/sequence_example.dart';
import 'package:oh_my_flutter_example/examples/text_motion_example.dart';
import 'package:oh_my_flutter_example/main.dart';

void main() {
  testWidgets(
    'when the example runs on a compact viewport, '
    'it should remain scrollable without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const UtilityExample());
      await tester.pump();

      expect(
        (
          tester.takeException(),
          find.byType(DeviceDisplayExample).evaluate().length,
          find.byType(DeviceLocationExample).evaluate().length,
          find.byType(RelativeTimeExample).evaluate().length,
          find.byType(MotionExample).evaluate().length,
          find.byType(TextMotionExample).evaluate().length,
          find.byType(MarqueeExample).evaluate().length,
          find.byType(MaybeSafeAreaExample).evaluate().length,
          find.byType(NativeSelectableTextExample).evaluate().length,
          find.byType(ControlledVisibilityExample).evaluate().length,
          find.byType(MorphExample).evaluate().length,
          find.byType(SequenceExample).evaluate().length,
          find.byType(RouteSettledExample).evaluate().length,
        ),
        (null, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1),
      );
    },
  );
}
