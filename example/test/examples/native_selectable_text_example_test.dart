import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter_example/examples/native_selectable_text_example.dart';

void main() {
  testWidgets(
    'when the NativeSelectableText example builds, '
    'it should demonstrate plain and rich text',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: NativeSelectableTextExample()),
        ),
      );

      final widgets = tester.widgetList<NativeSelectableText>(
        find.byType(NativeSelectableText),
      );

      expect(
        (
          widgets.length,
          widgets.first.data,
          widgets.last.textSpan?.toPlainText(),
        ),
        (
          2,
          'Plain text with emoji stays rendered by Flutter. 👋',
          'Styled text uses a native selection menu '
              'when the platform supports one.',
        ),
      );
    },
  );
}
