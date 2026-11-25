import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  testWidgets('when parent progress reverses, it should draw the supplied effect at each value', (tester) async {
    final progress = AnimationController(vsync: tester);
    addTearDown(progress.dispose);
    const key = ValueKey('driven child');
    await tester.pumpWidget(
      Center(
        child: Motion.driven(
          progress: progress,
          effect: const ScaleInMotionEffect(),
          child: const SizedBox(key: key, width: 100, height: 100),
        ),
      ),
    );
    final widths = <double>[];
    for (final value in [0.25, 1.0, 0.5]) {
      progress.value = value;
      await tester.pump();
      final box = tester.renderObject<RenderBox>(find.byKey(key));
      widths.add((box.localToGlobal(const Offset(100, 0)) - box.localToGlobal(Offset.zero)).dx);
    }
    expect(widths, [25, 100, 50]);
  });
}
