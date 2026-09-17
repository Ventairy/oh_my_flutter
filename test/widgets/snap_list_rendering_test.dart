import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'snap_list_test.dart' show SnapListTestHost;

class _Probe extends SingleChildRenderObjectWidget {
  const _Probe({required this.layout, required this.paint});
  final VoidCallback layout;
  final VoidCallback paint;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderProbe(layout, paint);
}

class _RenderProbe extends RenderBox {
  _RenderProbe(this.onLayout, this.onPaint);
  final VoidCallback onLayout;
  final VoidCallback onPaint;
  @override
  void performLayout() {
    onLayout();
    size = constraints.biggest;
  }

  @override
  void paint(PaintingContext context, Offset offset) => onPaint();
}

void main() {
  testWidgets('when a large eager list moves, it should avoid laying out its content on each animation frame', (
    tester,
  ) async {
    var layouts = 0;
    var distantPaints = 0;
    final controller = SnapListController();
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList(
          controller: controller,
          incomingTransitionBuilder: (_, progress, isReverse, child) => FadeTransition(opacity: progress, child: child),
          outgoingTransitionBuilder: (_, progress, isReverse, child) =>
              ScaleTransition(scale: Tween<double>(begin: 1, end: .9).animate(progress), child: child),
          children: List.generate(
            1000,
            (i) => _Probe(
              layout: () => layouts++,
              paint: () {
                if (i > 2) distantPaints++;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initialLayouts = layouts;
    final result = controller.next();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect((layouts - initialLayouts, distantPaints), (0, 0));
    await tester.pumpAndSettle();
    await result;
  });
}
