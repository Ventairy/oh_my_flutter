import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/contour/contour.dart' show ContourProcessorTestHarness;
import 'package:oh_my_flutter/src/widgets/contour/contour_work_budget.dart';

import 'contour_colored_box_admission_subclass.dart';
import 'contour_colored_box_admission_wide_widget.dart';
import 'contour_native_custom_color.dart';
import 'contour_test_harness.dart';
import 'contour_test_painter.dart';

void main() {
  const blue = Color(0xff2070d0);
  const box = SizedBox(width: 32, height: 30, child: ColoredBox(color: blue));

  Widget scene(GlobalKey contour, Widget source) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: Contour(key: contour, color: const Color(0xffffffff), amount: 3, child: source),
    ),
  );

  Object? diagnostic(GlobalKey contour, String name) => contour.currentContext!
      .findRenderObject()!
      .toDiagnosticsNode()
      .getProperties()
      .firstWhere((property) => property.name == name)
      .value;

  (Object?, Object?) admission(GlobalKey contour) => (
    diagnostic(contour, 'knownBoxFillActive'),
    diagnostic(contour, 'declaredPathActive'),
  );

  Future<void> cleanup(WidgetTester tester) async {
    await ContourTestHarness.settle(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    for (var attempt = 0; attempt < 200; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
      await tester.pump();
      if (!ContourProcessorTestHarness.stopping &&
          !ContourProcessorTestHarness.prepared &&
          ContourWorkBudget.shared.activeBytes == 0) {
        return;
      }
    }
    throw StateError('Colored-box fallback worker did not release its work capacity.');
  }

  final unsupported = <String, Widget>{
    'a ColoredBox subclass inherits the stock renderer': const SizedBox(
      width: 32,
      height: 30,
      child: ContourColoredBoxAdmissionSubclass(),
    ),
    'a ColoredBox fill is translucent': const SizedBox(
      width: 32,
      height: 30,
      child: ColoredBox(color: Color(0x802070d0)),
    ),
    'a ColoredBox fill is transparent': const SizedBox(
      width: 32,
      height: 30,
      child: ColoredBox(color: Color(0x002070d0)),
    ),
    'a fractional ColoredBox alpha rounds to opaque ARGB': const SizedBox(
      width: 32,
      height: 30,
      child: ColoredBox(color: Color.from(alpha: .9999, red: .2, green: .4, blue: .8)),
    ),
    'a ColoredBox fill uses a custom Color subclass': const SizedBox(
      width: 32,
      height: 30,
      child: ColoredBox(color: ContourNativeCustomColor()),
    ),
    'a ColoredBox disables antialiasing': const SizedBox(
      width: 32,
      height: 30,
      child: ColoredBox(color: blue, isAntiAlias: false),
    ),
    'a Container color is translucent': Container(width: 32, height: 30, color: const Color(0x802070d0)),
    'a Container color is transparent': Container(width: 32, height: 30, color: const Color(0x002070d0)),
    'a Container color disables antialiasing': Container(width: 32, height: 30, color: blue, isAntiAlias: false),
    'a ColoredBox has a painted child': const SizedBox(
      width: 32,
      height: 30,
      child: ColoredBox(
        color: blue,
        child: CustomPaint(painter: ContourTestPainter(circle: true)),
      ),
    ),
    'a ColoredBox child paints beyond the box': const SizedBox(
      width: 32,
      height: 30,
      child: ColoredBox(
        color: blue,
        child: OverflowBox(
          minWidth: 70,
          maxWidth: 70,
          minHeight: 60,
          maxHeight: 60,
          child: ColoredBox(color: Color(0xffd02040)),
        ),
      ),
    ),
    'a source ancestor changes the box opacity': const Opacity(opacity: .5, child: box),
    'a source ancestor clips the box': const ClipRRect(borderRadius: BorderRadius.all(Radius.circular(6)), child: box),
    'a source transform filters the box': Transform(
      transform: Matrix4.identity(),
      filterQuality: FilterQuality.low,
      child: box,
    ),
    'a ColoredBox is narrower than the known-box admission margin': const SizedBox(
      width: .5,
      height: 30,
      child: ColoredBox(color: blue),
    ),
    'a ColoredBox exceeds the known-box sampled-area limit': const SizedBox(
      width: 500,
      height: 500,
      child: ColoredBox(color: blue),
    ),
    'a source transform collapses the box to a line': Transform(
      transform: Matrix4.diagonal3Values(0, 1, 1),
      child: box,
    ),
  };

  for (final entry in unsupported.entries) {
    testWidgets('when ${entry.key}, it should retain sampled fallback', (tester) async {
      addTearDown(() => cleanup(tester));
      final contour = GlobalKey();
      await tester.pumpWidget(scene(contour, entry.value));
      expect(admission(contour), (false, false));
    });
  }

  testWidgets('when an unknown element exposes wide traversal, it should reject it without visiting its children', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    final contour = GlobalKey();
    var visits = 0;
    await tester.pumpWidget(
      scene(
        contour,
        ContourColoredBoxAdmissionWideWidget(onVisit: () => visits++, child: box),
      ),
    );
    expect((admission(contour), visits), ((false, false), 0));
  });

  testWidgets('when more than sixty-four element wrappers separate a box, it should retain sampled fallback', (
    tester,
  ) async {
    addTearDown(() => cleanup(tester));
    final contour = GlobalKey();
    Widget source = box;
    for (var depth = 0; depth < 70; depth++) {
      final child = source;
      source = Builder(builder: (_) => child);
    }
    await tester.pumpWidget(scene(contour, source));
    expect(admission(contour), (false, false));
  });
}
