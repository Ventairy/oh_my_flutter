import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

void main() {
  testWidgets(
    'when web text is only tapped, it should not change the browser context menu',
    (tester) async {
      var platformCallCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.contextMenu,
        (_) async {
          platformCallCount += 1;
          return null;
        },
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NativeSelectableText('Web tap'),
          ),
        ),
      );

      await tester.tap(find.text('Web tap'));
      await tester.pump();

      expect((platformCallCount, BrowserContextMenu.enabled), (0, true));
    },
    skip: !kIsWeb,
  );

  testWidgets(
    'when running on web, it should use Flutter adaptive selection',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.contextMenu,
        (_) async => null,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NativeSelectableText('Web selection'),
          ),
        ),
      );

      await tester.longPress(find.text('Web selection'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect((find.text('Copy').evaluate().length, BrowserContextMenu.enabled), (1, true));
    },
    skip: !kIsWeb,
  );
}
