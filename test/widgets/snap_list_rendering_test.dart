import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

import 'snap_list_test.dart' show SnapListTestHost;

class _Probe extends SingleChildRenderObjectWidget {
  const new({required this.layout, required this.paint});
  final VoidCallback layout;
  final VoidCallback paint;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderProbe(layout, paint);
}

class _RenderProbe extends RenderBox {
  new(this.onLayout, this.onPaint);
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
  testWidgets('when earlier items scroll without clipping, it should retain the prepared trailer paint', (
    tester,
  ) async {
    var layouts = 0;
    var paints = 0;
    await tester.pumpWidget(
      SnapListTestHost.app(
        SnapList.builder(
          clipBehavior: Clip.none,
          itemCount: 1000,
          cacheItemCount: 0,
          itemBuilder: (_, _) => const SizedBox.expand(),
          trailingBuilder: (_) => SizedBox(
            height: 100,
            child: _Probe(layout: () => layouts++, paint: () => paints++),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final initial = (layouts, paints);
    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    for (final pixels in [20.0, 50.0, 100.0, 50.0, 0.0]) {
      position.jumpTo(pixels);
      await tester.pump();
    }
    expect((layouts - initial.$1, paints - initial.$2), (0, 0));
  });

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
          incomingTransitionBuilder: (_, progress, details, child) => FadeTransition(opacity: progress, child: child),
          outgoingTransitionBuilder: (_, progress, details, child) =>
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
