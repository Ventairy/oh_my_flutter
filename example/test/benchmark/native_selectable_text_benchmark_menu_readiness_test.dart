import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/native_selectable_text/pigeon/native_selectable_text.g.dart';

import '../../benchmark/native_selectable_text/menu_readiness.dart';

const _showChannelName =
    'dev.flutter.pigeon.oh_my_flutter.'
    'NativeSelectableTextMenuHostApi.show';
const _hideChannelName =
    'dev.flutter.pigeon.oh_my_flutter.'
    'NativeSelectableTextMenuHostApi.hide';

void _acceptNativeMenuPresentations() {
  final binding = TestDefaultBinaryMessengerBinding.instance;
  binding.defaultBinaryMessenger
    ..setMockDecodedMessageHandler<Object?>(
      const BasicMessageChannel<Object?>(
        _showChannelName,
        NativeSelectableTextMenuHostApi.pigeonChannelCodec,
      ),
      (_) async => <Object?>[true],
    )
    ..setMockDecodedMessageHandler<Object?>(
      const BasicMessageChannel<Object?>(
        _hideChannelName,
        NativeSelectableTextMenuHostApi.pigeonChannelCodec,
      ),
      (_) async => <Object?>[],
    );
}

Future<(GlobalKey, EditableTextState)> _showNativeMenu(
  WidgetTester tester,
) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    _acceptNativeMenuPresentations();
    final rootKey = GlobalKey();
    await tester.pumpWidget(
      KeyedSubtree(
        key: rootKey,
        child: const MaterialApp(
          home: Scaffold(
            body: NativeSelectableText('Native benchmark selection'),
          ),
        ),
      ),
    );
    await tester.longPress(find.text('Native benchmark selection'));
    await tester.pump();
    await tester.pump();
    final editableTextState = tester.state<EditableTextState>(
      find.descendant(
        of: find.byType(NativeSelectableText),
        matching: find.byType(EditableText),
      ),
    );
    return (rootKey, editableTextState);
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    ContextMenuController.removeAny();
  });

  group('NativeSelectableTextBenchmarkMenuReadiness', () {
    testWidgets(
      'when the tree has no benchmark target, it should reject native timing',
      (tester) async {
        final rootKey = GlobalKey();
        await tester.pumpWidget(
          KeyedSubtree(
            key: rootKey,
            child: const MaterialApp(home: SizedBox()),
          ),
        );

        final readiness = NativeSelectableTextBenchmarkMenuReadiness.inspect(
          rootKey.currentContext! as Element,
        );

        expect(readiness.isReady, isFalse);
      },
    );

    testWidgets(
      'when native text has no open selection menu, '
      'it should reject native timing',
      (tester) async {
        final rootKey = GlobalKey();
        await tester.pumpWidget(
          KeyedSubtree(
            key: rootKey,
            child: const MaterialApp(
              home: NativeSelectableText('No menu'),
            ),
          ),
        );

        final readiness = NativeSelectableTextBenchmarkMenuReadiness.inspect(
          rootKey.currentContext! as Element,
        );

        expect(readiness.isReady, isFalse);
      },
    );

    testWidgets(
      'when native text owns an open menu for a selection, '
      'it should accept native timing',
      (tester) async {
        final target = await _showNativeMenu(tester);

        final readiness = NativeSelectableTextBenchmarkMenuReadiness.inspect(
          target.$1.currentContext! as Element,
        );

        expect(readiness.isReady, isTrue);
      },
    );

    testWidgets(
      'when the native menu is dismissed after readiness, '
      'it should reject ongoing timing',
      (tester) async {
        final target = await _showNativeMenu(tester);
        target.$2.hideToolbar(false);
        await tester.pump();

        final readiness = NativeSelectableTextBenchmarkMenuReadiness.inspect(
          target.$1.currentContext! as Element,
        );

        expect(readiness.isReady, isFalse);
      },
    );

    testWidgets(
      'when an adaptive toolbar is mounted, it should reject native timing',
      (tester) async {
        final rootKey = GlobalKey();
        await tester.pumpWidget(
          KeyedSubtree(
            key: rootKey,
            child: MaterialApp(
              home: AdaptiveTextSelectionToolbar.buttonItems(
                anchors: const TextSelectionToolbarAnchors(
                  primaryAnchor: Offset.zero,
                ),
                buttonItems: <ContextMenuButtonItem>[
                  ContextMenuButtonItem(
                    label: 'Copy',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        final readiness = NativeSelectableTextBenchmarkMenuReadiness.inspect(
          rootKey.currentContext! as Element,
        );

        expect(
          (
            isReady: readiness.isReady,
            adaptiveToolbarDetected: readiness.adaptiveToolbarDetected,
          ),
          (
            isReady: false,
            adaptiveToolbarDetected: true,
          ),
        );
      },
    );

    testWidgets(
      'when an adaptive toolbar replaced the native menu, '
      'it should explain how to make the run valid',
      (tester) async {
        final rootKey = GlobalKey();
        await tester.pumpWidget(
          KeyedSubtree(
            key: rootKey,
            child: MaterialApp(
              home: AdaptiveTextSelectionToolbar.buttonItems(
                anchors: const TextSelectionToolbarAnchors(
                  primaryAnchor: Offset.zero,
                ),
                buttonItems: <ContextMenuButtonItem>[
                  ContextMenuButtonItem(
                    label: 'Copy',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        final readiness = NativeSelectableTextBenchmarkMenuReadiness.inspect(
          rootKey.currentContext! as Element,
        );

        expect(
          readiness.requireNativeMenu,
          throwsA(
            isA<StateError>()
                .having(
                  (error) => error.message,
                  'message',
                  contains("would measure Flutter's adaptive fallback"),
                )
                .having(
                  (error) => error.message,
                  'next action',
                  contains('Fix the native host or device state'),
                ),
          ),
        );
      },
    );
  });
}
