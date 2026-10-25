import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../benchmark/contour/main.dart' as benchmark;

void main() {
  testWidgets('when unique artwork is requested, it should render forty distinct fixed-size samples', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/?enabled=false&unique=true&count=40';
    addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

    benchmark.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    final labels = tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).toList();
    final icons = tester.widgetList<Icon>(find.byType(Icon)).map((icon) => icon.icon?.codePoint).toList();
    final samples = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .where((box) => box.width == 48 && box.height == 48);
    final result = <String, Object>{
      'labels': labels,
      'icon_count': icons.length,
      'distinct_icons': icons.toSet().length,
      'fixed_size_samples': samples.length,
    };
    await tester.pumpWidget(const SizedBox.shrink());

    expect(result, <String, Object>{
      'labels': List.generate(20, (index) => 'T$index'),
      'icon_count': 20,
      'distinct_icons': 20,
      'fixed_size_samples': 40,
    });
  });
}
