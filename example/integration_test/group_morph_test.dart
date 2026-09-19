import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter_example/examples/group_morph_example.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('when grouped content expands and reverses, '
      'it should keep the nested title independent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [MorphNavigatorObserver()],
        home: const Scaffold(
          body: SafeArea(
            child: Padding(padding: EdgeInsets.all(24), child: GroupMorphExample()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expand card'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final screenshots = await Directory.systemTemp.createTemp('group_morph_');
    await File('${screenshots.path}/midflight.png').writeAsBytes(await binding.takeScreenshot('group_morph_midflight'));
    debugPrint('Group screenshot: ${screenshots.path}/midflight.png');
    await tester.tap(find.text('Return card'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Expand card'));
    await tester.pumpAndSettle();
    await File('${screenshots.path}/settled.png').writeAsBytes(await binding.takeScreenshot('group_morph_settled'));
    debugPrint('Group screenshot: ${screenshots.path}/settled.png');
    await tester.tap(find.text('Return card'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
