import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/src/widgets/motion/internals/motion_shader_preparation.dart';

void main() {
  testWidgets('when frames interrupt shader preparation, it should renew both quiet intervals', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    var loaded = false;
    var warmed = false;
    MotionShaderPreparation.schedule(() {
      loaded = true;
      MotionShaderPreparation.schedule(() => warmed = true, waitForQuiet: true);
    }, waitForQuiet: true);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox(width: 1));
    await tester.pump(const Duration(milliseconds: 149));
    final loadedBeforeRenewedInterval = loaded;
    await tester.pump(const Duration(milliseconds: 1));
    final loadedAfterRenewedInterval = loaded;

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox(width: 2));
    await tester.pump(const Duration(milliseconds: 149));
    final warmedBeforeRenewedInterval = warmed;
    await tester.pump(const Duration(milliseconds: 1));

    expect(
      (loadedBeforeRenewedInterval, loadedAfterRenewedInterval, warmedBeforeRenewedInterval, warmed),
      (false, true, false, true),
    );
  });
}
