import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';
import 'package:oh_my_flutter/src/widgets/native_selectable_text/pigeon/native_selectable_text.g.dart';

const _showChannelName = 'dev.flutter.pigeon.oh_my_flutter.NativeSelectableTextMenuHostApi.show';
const _updateChannelName = 'dev.flutter.pigeon.oh_my_flutter.NativeSelectableTextMenuHostApi.update';
const _updateGeometryChannelName = 'dev.flutter.pigeon.oh_my_flutter.NativeSelectableTextMenuHostApi.updateGeometry';
const _hideChannelName = 'dev.flutter.pigeon.oh_my_flutter.NativeSelectableTextMenuHostApi.hide';
const _actionChannelName = 'dev.flutter.pigeon.oh_my_flutter.NativeSelectableTextMenuFlutterApi.onAction';
const _dismissedChannelName = 'dev.flutter.pigeon.oh_my_flutter.NativeSelectableTextMenuFlutterApi.onDismissed';

Widget _testApp(
  Widget child, {
  Widget? outside,
  Locale? locale,
  Iterable<LocalizationsDelegate<dynamic>> localizationsDelegates = const [],
  Iterable<Locale> supportedLocales = const <Locale>[Locale('en', 'US')],
  bool? supportsShowingSystemContextMenu,
}) {
  final selectableChild = supportsShowingSystemContextMenu == null
      ? child
      : MediaQuery(
          data: MediaQueryData(
            supportsShowingSystemContextMenu: supportsShowingSystemContextMenu,
          ),
          child: child,
        );
  return MaterialApp(
    locale: locale,
    localizationsDelegates: localizationsDelegates,
    supportedLocales: supportedLocales,
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [selectableChild, const SizedBox(height: 80), ?outside],
        ),
      ),
    ),
  );
}

Future<void> _showSelectionMenu(WidgetTester tester, Finder text) async {
  await tester.longPress(text);
  await tester.pump();
  await tester.pump();
}

EditableTextState _editableTextState(WidgetTester tester) {
  return tester.state<EditableTextState>(
    find.descendant(
      of: find.byType(NativeSelectableText),
      matching: find.byType(EditableText),
    ),
  );
}

void _setTargetPlatform(TargetPlatform platform) {
  debugDefaultTargetPlatformOverride = platform;
}

void _restoreTargetPlatform() => debugDefaultTargetPlatformOverride = null;

final class _NativeMenuHost {
  _NativeMenuHost({
    this.acceptsPresentation = true,
    bool? acceptsUpdates,
    bool? acceptsGeometryUpdates,
    this.deferShowResponses = false,
    this.deferUpdateResponses = false,
    this.deferGeometryUpdateResponses = false,
  }) : acceptsUpdates = acceptsUpdates ?? acceptsPresentation,
       acceptsGeometryUpdates = acceptsGeometryUpdates ?? acceptsUpdates ?? acceptsPresentation;

  final bool acceptsPresentation;
  bool acceptsUpdates;
  bool acceptsGeometryUpdates;
  final bool deferShowResponses;
  final bool deferUpdateResponses;
  final bool deferGeometryUpdateResponses;
  final List<NativeSelectableTextMenuRequestMessage> showRequests = [];
  final List<NativeSelectableTextMenuRequestMessage> updateRequests = [];
  final List<(int, Float64List)> geometryUpdates = [];
  final List<int> hiddenSessions = [];
  final Queue<Completer<void>> _pendingResponses = Queue<Completer<void>>();
  int _inFlightOperations = 0;
  int maxInFlightOperations = 0;

  int get pendingResponseCount => _pendingResponses.length;

  TestDefaultBinaryMessenger get _messenger => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void setUp() {
    _messenger.setMockDecodedMessageHandler<Object?>(
      const BasicMessageChannel<Object?>(
        _showChannelName,
        NativeSelectableTextMenuHostApi.pigeonChannelCodec,
      ),
      (message) async {
        final arguments = message! as List<Object?>;
        showRequests.add(arguments.single! as NativeSelectableTextMenuRequestMessage);
        return _respond(
          accepted: acceptsPresentation,
          deferred: deferShowResponses,
        );
      },
    );
    _messenger.setMockDecodedMessageHandler<Object?>(
      const BasicMessageChannel<Object?>(
        _updateChannelName,
        NativeSelectableTextMenuHostApi.pigeonChannelCodec,
      ),
      (message) async {
        final arguments = message! as List<Object?>;
        updateRequests.add(arguments.single! as NativeSelectableTextMenuRequestMessage);
        return _respond(
          accepted: acceptsUpdates,
          deferred: deferUpdateResponses,
        );
      },
    );
    _messenger.setMockDecodedMessageHandler<Object?>(
      const BasicMessageChannel<Object?>(
        _updateGeometryChannelName,
        NativeSelectableTextMenuHostApi.pigeonChannelCodec,
      ),
      (message) async {
        final arguments = message! as List<Object?>;
        geometryUpdates.add((arguments[0]! as int, arguments[1]! as Float64List));
        return _respond(
          accepted: acceptsGeometryUpdates,
          deferred: deferGeometryUpdateResponses,
        );
      },
    );
    _messenger.setMockDecodedMessageHandler<Object?>(
      const BasicMessageChannel<Object?>(
        _hideChannelName,
        NativeSelectableTextMenuHostApi.pigeonChannelCodec,
      ),
      (message) async {
        final arguments = message! as List<Object?>;
        hiddenSessions.add(arguments.single! as int);
        return <Object?>[];
      },
    );
  }

  void completeNextResponse() {
    _pendingResponses.removeFirst().complete();
  }

  void completeLastResponse() {
    _pendingResponses.removeLast().complete();
  }

  Future<List<Object?>> _respond({required bool accepted, required bool deferred}) async {
    _inFlightOperations += 1;
    maxInFlightOperations = math.max(
      maxInFlightOperations,
      _inFlightOperations,
    );
    try {
      if (deferred) {
        final response = Completer<void>();
        _pendingResponses.add(response);
        await response.future;
      }
      return <Object?>[accepted];
    } finally {
      _inFlightOperations -= 1;
    }
  }

  Future<void> sendAction({required int sessionIdentifier, required int actionIdentifier}) {
    return _sendFlutterMessage(
      _actionChannelName,
      <Object?>[sessionIdentifier, actionIdentifier],
    );
  }

  Future<void> sendDismissed({required int sessionIdentifier, required bool actionInvoked}) {
    return _sendFlutterMessage(
      _dismissedChannelName,
      <Object?>[sessionIdentifier, actionInvoked],
    );
  }

  Future<void> _sendFlutterMessage(String channelName, Object message) async {
    final response = Completer<ByteData?>();
    await _messenger.handlePlatformMessage(
      channelName,
      NativeSelectableTextMenuFlutterApi.pigeonChannelCodec.encodeMessage(message),
      response.complete,
    );
    await response.future;
  }
}

final class _LocalizedMenuDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _LocalizedMenuDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    return SynchronousFuture<MaterialLocalizations>(
      locale.languageCode == 'pt' ? const _LocalizedMenuLabels() : const DefaultMaterialLocalizations(),
    );
  }

  @override
  bool shouldReload(_LocalizedMenuDelegate old) => false;
}

final class _LocalizedMenuLabels extends DefaultMaterialLocalizations {
  const _LocalizedMenuLabels();

  @override
  String get copyButtonLabel => 'Copiar texto';

  @override
  String get selectAllButtonLabel => 'Selecionar tudo';
}

final class _LocalizedCupertinoDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const _LocalizedCupertinoDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    return SynchronousFuture<CupertinoLocalizations>(
      const DefaultCupertinoLocalizations(),
    );
  }

  @override
  bool shouldReload(_LocalizedCupertinoDelegate old) => false;
}

final class _CountingMenuDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _CountingMenuDelegate(this.labels);

  final _CountingMenuLabels labels;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    return SynchronousFuture<MaterialLocalizations>(labels);
  }

  @override
  bool shouldReload(_CountingMenuDelegate old) => false;
}

final class _CountingMenuLabels extends DefaultMaterialLocalizations {
  int copyLabelRequestCount = 0;

  @override
  String get copyButtonLabel {
    copyLabelRequestCount += 1;
    return super.copyButtonLabel;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('when plain text is built, it should forward the original string', (tester) async {
    await tester.pumpWidget(_testApp(const NativeSelectableText('Hello 👋')));

    expect(tester.widget<SelectableText>(find.byType(SelectableText)).data, 'Hello 👋');
  });

  testWidgets('when rich text is built, it should forward the original span', (tester) async {
    const textSpan = TextSpan(
      text: 'Hello ',
      children: [
        TextSpan(
          text: 'world',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
    await tester.pumpWidget(_testApp(const NativeSelectableText.rich(textSpan)));

    expect(tester.widget<SelectableText>(find.byType(SelectableText)).textSpan, same(textSpan));
  });

  testWidgets('when options are supplied, it should forward every nondeprecated option', (tester) async {
    final focusNode = FocusNode();
    const style = TextStyle(fontSize: 17);
    const strutStyle = StrutStyle(height: 1.4);
    const textScaler = TextScaler.linear(1.2);
    const cursorRadius = Radius.circular(3);
    const scrollPhysics = BouncingScrollPhysics();
    const scrollBehavior = MaterialScrollBehavior();
    const textHeightBehavior = TextHeightBehavior(applyHeightToFirstAscent: false);
    const magnifierConfiguration = TextMagnifierConfiguration.disabled;
    void onTap() {}
    void onSelectionChanged(TextSelection selection, SelectionChangedCause? cause) {}

    await tester.pumpWidget(
      _testApp(
        NativeSelectableText(
          'Forwarded',
          focusNode: focusNode,
          style: style,
          strutStyle: strutStyle,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          textScaler: textScaler,
          showCursor: true,
          autofocus: true,
          minLines: 2,
          maxLines: 3,
          cursorWidth: 4,
          cursorHeight: 20,
          cursorRadius: cursorRadius,
          cursorColor: Colors.red,
          selectionColor: Colors.blue,
          selectionHeightStyle: ui.BoxHeightStyle.max,
          selectionWidthStyle: ui.BoxWidthStyle.max,
          dragStartBehavior: DragStartBehavior.down,
          enableInteractiveSelection: false,
          selectionControls: materialTextSelectionHandleControls,
          onTap: onTap,
          scrollPhysics: scrollPhysics,
          scrollBehavior: scrollBehavior,
          semanticsLabel: 'Accessible text',
          textHeightBehavior: textHeightBehavior,
          textWidthBasis: TextWidthBasis.longestLine,
          onSelectionChanged: onSelectionChanged,
          magnifierConfiguration: magnifierConfiguration,
        ),
      ),
    );
    final selectableText = tester.widget<SelectableText>(find.byType(SelectableText));

    expect(
      (
        selectableText.focusNode,
        selectableText.style,
        selectableText.strutStyle,
        selectableText.textAlign,
        selectableText.textDirection,
        selectableText.textScaler,
        selectableText.showCursor,
        selectableText.autofocus,
        selectableText.minLines,
        selectableText.maxLines,
        selectableText.cursorWidth,
        selectableText.cursorHeight,
        selectableText.cursorRadius,
        selectableText.cursorColor,
        selectableText.selectionColor,
        selectableText.selectionHeightStyle,
        selectableText.selectionWidthStyle,
        selectableText.dragStartBehavior,
        selectableText.enableInteractiveSelection,
        selectableText.selectionControls,
        selectableText.onTap,
        selectableText.scrollPhysics,
        selectableText.scrollBehavior,
        selectableText.semanticsLabel,
        selectableText.textHeightBehavior,
        selectableText.textWidthBasis,
        selectableText.onSelectionChanged,
        selectableText.magnifierConfiguration,
      ),
      (
        focusNode,
        style,
        strutStyle,
        TextAlign.center,
        TextDirection.rtl,
        textScaler,
        true,
        true,
        2,
        3,
        4.0,
        20.0,
        cursorRadius,
        Colors.red,
        Colors.blue,
        ui.BoxHeightStyle.max,
        ui.BoxWidthStyle.max,
        DragStartBehavior.down,
        false,
        materialTextSelectionHandleControls,
        onTap,
        scrollPhysics,
        scrollBehavior,
        'Accessible text',
        textHeightBehavior,
        TextWidthBasis.longestLine,
        onSelectionChanged,
        magnifierConfiguration,
      ),
    );
    focusNode.dispose();
  });

  test('when legacy selection controls are supplied, it should reject toolbar replacement', () {
    // This intentionally exercises Flutter's deprecated toolbar-owning controls.
    expect(() => NativeSelectableText('Text', selectionControls: materialTextSelectionControls), throwsAssertionError);
  });

  testWidgets('when no menu is requested, it should perform no platform work', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost()..setUp();
    await tester.pumpWidget(_testApp(const NativeSelectableText('No selection yet')));

    _restoreTargetPlatform();
    expect((host.showRequests.length, host.updateRequests.length, host.hiddenSessions.length), (0, 0, 0));
  });

  testWidgets('when native text is built, it should register one text-field tap region', (tester) async {
    await tester.pumpWidget(_testApp(const NativeSelectableText('One tap region')));

    expect(find.byType(TextFieldTapRegion), findsOneWidget);
  });

  testWidgets('when Android accepts a menu, it should route commands to the native host', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost()..setUp();
    await tester.pumpWidget(_testApp(const NativeSelectableText('Native selection')));
    await _showSelectionMenu(tester, find.text('Native selection'));

    _restoreTargetPlatform();
    expect((host.showRequests.length, find.text('Copy').evaluate().length), (1, 0));
  });

  testWidgets('when the platform is unsupported, it should use the adaptive toolbar', (tester) async {
    _setTargetPlatform(TargetPlatform.fuchsia);
    final host = _NativeMenuHost()..setUp();
    await tester.pumpWidget(_testApp(const NativeSelectableText('Adaptive selection')));
    await _showSelectionMenu(tester, find.text('Adaptive selection'));

    _restoreTargetPlatform();
    expect((host.showRequests.length, find.text('Copy').evaluate().length), (0, 1));
  });

  testWidgets('when iOS lacks system menu support, it should use the adaptive toolbar', (tester) async {
    _setTargetPlatform(TargetPlatform.iOS);
    final host = _NativeMenuHost()..setUp();
    await tester.pumpWidget(
      _testApp(
        const NativeSelectableText('Older iOS selection'),
        supportsShowingSystemContextMenu: false,
      ),
    );
    await _showSelectionMenu(tester, find.text('Older iOS selection'));

    _restoreTargetPlatform();
    expect((host.showRequests.length, find.text('Copy').evaluate().length), (0, 1));
  });

  testWidgets('when the native host is missing, it should fall back to the adaptive toolbar', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      _showChannelName,
      (_) async => null,
    );
    await tester.pumpWidget(_testApp(const NativeSelectableText('Fallback selection')));
    await _showSelectionMenu(tester, find.text('Fallback selection'));
    await tester.pumpAndSettle();

    _restoreTargetPlatform();
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('when the native host rejects presentation, it should fall back immediately', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost(acceptsPresentation: false)..setUp();
    await tester.pumpWidget(_testApp(const NativeSelectableText('Rejected selection')));
    await _showSelectionMenu(tester, find.text('Rejected selection'));

    _restoreTargetPlatform();
    expect((host.showRequests.length, find.text('Copy').evaluate().length), (1, 1));
  });

  testWidgets('when adaptive fallback selection changes, it should refresh the available actions', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    _NativeMenuHost(acceptsPresentation: false).setUp();
    const text = 'Refresh adaptive fallback actions';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await _showSelectionMenu(tester, find.text(text));
    final editableTextState = _editableTextState(tester);

    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: text.length),
      ),
      SelectionChangedCause.keyboard,
    );
    await tester.pump();

    _restoreTargetPlatform();
    expect(find.text('Select all'), findsNothing);
  });

  testWidgets('when a menu is localized, it should send Flutter localized command labels', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost()..setUp();
    await tester.pumpWidget(
      _testApp(
        const NativeSelectableText('Texto localizado'),
        locale: const Locale('pt'),
        localizationsDelegates: const [
          _LocalizedMenuDelegate(),
          _LocalizedCupertinoDelegate(),
        ],
        supportedLocales: const <Locale>[Locale('en'), Locale('pt')],
      ),
    );
    await _showSelectionMenu(tester, find.text('Texto localizado'));

    _restoreTargetPlatform();
    expect(host.showRequests.single.items.map((item) => item.label), contains('Copiar texto'));
  });

  testWidgets('when selection opens a native menu, it should send global selection geometry', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost()..setUp();
    await tester.pumpWidget(_testApp(const NativeSelectableText('Geometry selection')));
    await _showSelectionMenu(tester, find.text('Geometry selection'));
    final editableTextState = _editableTextState(tester);
    final glyphHeights = editableTextState.getGlyphHeights();
    final expectedRectangle = TextSelectionToolbarAnchors.getSelectionRect(
      editableTextState.renderEditable,
      glyphHeights.startGlyphHeight,
      glyphHeights.endGlyphHeight,
      editableTextState.renderEditable.getEndpointsForSelection(editableTextState.textEditingValue.selection),
    );
    final request = host.showRequests.single;

    _restoreTargetPlatform();
    expect(
      (
        Rect.fromLTRB(
          request.selectionRectangle.left,
          request.selectionRectangle.top,
          request.selectionRectangle.right,
          request.selectionRectangle.bottom,
        ),
        Offset(request.primaryAnchor.dx, request.primaryAnchor.dy),
      ),
      (expectedRectangle, editableTextState.contextMenuAnchors.primaryAnchor),
    );
  });

  testWidgets('when a secondary click opens a native menu, it should preserve the pointer anchor', (tester) async {
    _setTargetPlatform(TargetPlatform.linux);
    final host = _NativeMenuHost()..setUp();
    const text = 'Secondary-click anchor';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    final pointerPosition = tester.getCenter(find.text(text));

    await tester.tapAt(
      pointerPosition,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump();
    await tester.pump();
    final request = host.showRequests.single;

    _restoreTargetPlatform();
    expect(
      Offset(request.primaryAnchor.dx, request.primaryAnchor.dy),
      pointerPosition,
    );
  });

  testWidgets('when native Select All is chosen, it should invoke Flutter selection behavior', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost()..setUp();
    const text = 'Select only one word';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await _showSelectionMenu(tester, find.text(text));
    final request = host.showRequests.single;
    final selectAll = request.items.singleWhere((item) => item.label == 'Select all');

    await host.sendAction(sessionIdentifier: request.sessionIdentifier, actionIdentifier: selectAll.identifier);
    await tester.pump();

    _restoreTargetPlatform();
    expect(
      _editableTextState(tester).textEditingValue.selection,
      const TextSelection(baseOffset: 0, extentOffset: text.length),
    );
  });

  testWidgets('when selection changes while native menu is visible, it should update the same session', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost()..setUp();
    const text = 'Update this selection';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await _showSelectionMenu(tester, find.text(text));
    final initialRequest = host.showRequests.single;
    final editableTextState = _editableTextState(tester);

    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: text.length),
      ),
      SelectionChangedCause.keyboard,
    );
    await tester.pump();
    await tester.pump();

    _restoreTargetPlatform();
    expect(
      (
        host.updateRequests.length,
        host.updateRequests.firstOrNull?.sessionIdentifier,
        host.updateRequests.firstOrNull?.selectionRectangle != initialRequest.selectionRectangle,
      ),
      (1, initialRequest.sessionIdentifier, true),
    );
  });

  testWidgets('when a visible macOS selection loses every action, it should close and reopen with a new session', (
    tester,
  ) async {
    _setTargetPlatform(TargetPlatform.macOS);
    addTearDown(_restoreTargetPlatform);
    var clipboardWriteCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardWriteCount += 1;
        }
        return null;
      },
    );
    final host = _NativeMenuHost()..setUp();
    const text = 'Collapse this macOS selection and reopen it safely';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await tester.tap(find.text(text));
    await tester.pump();
    final editableTextState = _editableTextState(tester);
    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: 8),
      ),
      SelectionChangedCause.keyboard,
    );
    editableTextState.showToolbar();
    await tester.pump();
    await tester.pump();
    final initialRequest = host.showRequests.single;
    final initialCopy = initialRequest.items.singleWhere((item) => item.label == 'Copy');

    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection.collapsed(offset: 8),
      ),
      SelectionChangedCause.keyboard,
    );
    await tester.pump();
    await tester.pump();
    final collapsedActionCount = editableTextState.contextMenuButtonItems.length;

    const reopenedSelection = TextSelection(baseOffset: 9, extentOffset: 13);
    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(selection: reopenedSelection),
      SelectionChangedCause.keyboard,
    );
    editableTextState.showToolbar();
    await tester.pump();
    await tester.pump();
    final reopenedRequest = host.showRequests.last;
    await host.sendAction(
      sessionIdentifier: initialRequest.sessionIdentifier,
      actionIdentifier: initialCopy.identifier,
    );
    await tester.pump();

    _restoreTargetPlatform();
    expect(
      (
        collapsedActionCount,
        host.hiddenSessions.singleOrNull,
        host.showRequests.length,
        reopenedRequest.sessionIdentifier != initialRequest.sessionIdentifier,
        clipboardWriteCount,
        editableTextState.textEditingValue.selection,
      ),
      (0, initialRequest.sessionIdentifier, 2, true, 0, reopenedSelection),
    );
  });

  testWidgets('when the context menu overlay rebuilds, it should retain the native bridge widget', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    addTearDown(_restoreTargetPlatform);
    _NativeMenuHost().setUp();
    const text = 'Retain this native menu bridge across selection changes';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await _showSelectionMenu(tester, find.text(text));
    final bridgeFinder = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_NativeSelectableTextMenuBridge',
    );
    final initialBridge = tester.widget(bridgeFinder);
    final editableTextState = _editableTextState(tester);

    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 2, extentOffset: 20),
      ),
      SelectionChangedCause.drag,
    );
    await tester.pump();

    _restoreTargetPlatform();
    expect(tester.widget(bridgeFinder), same(initialBridge));
  });

  testWidgets('when unchanged menu geometry is rebuilt, it should reuse the enumerated actions', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    addTearDown(_restoreTargetPlatform);
    final labels = _CountingMenuLabels();
    _NativeMenuHost().setUp();
    const text = 'Reuse these native menu actions';
    await tester.pumpWidget(
      _testApp(
        const NativeSelectableText(text),
        localizationsDelegates: <LocalizationsDelegate<dynamic>>[
          _CountingMenuDelegate(labels),
        ],
      ),
    );
    await _showSelectionMenu(tester, find.text(text));
    final initialCopyLabelRequestCount = labels.copyLabelRequestCount;
    final bridge = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_NativeSelectableTextMenuBridge',
    );

    tester.element(bridge).markNeedsBuild();
    await tester.pump();
    await tester.pump();

    _restoreTargetPlatform();
    expect(labels.copyLabelRequestCount, initialCopyLabelRequestCount);
  });

  testWidgets('when only selection geometry changes, it should send one packed geometry update', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost()..setUp();
    const text = 'Move this partial selection without changing its native actions';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await _showSelectionMenu(tester, find.text(text));
    final editableTextState = _editableTextState(tester);

    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: 12),
      ),
      SelectionChangedCause.keyboard,
    );
    await tester.pump();
    await tester.pump();
    final actionTableUpdate = host.updateRequests.single;

    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 2, extentOffset: 16),
      ),
      SelectionChangedCause.keyboard,
    );
    await tester.pump();
    await tester.pump();
    final geometryUpdate = host.geometryUpdates.singleOrNull;
    final geometry = geometryUpdate?.$2;
    final updatedRectangle = geometry == null
        ? null
        : Rect.fromLTRB(geometry[0], geometry[1], geometry[2], geometry[3]);
    final initialRectangle = Rect.fromLTRB(
      actionTableUpdate.selectionRectangle.left,
      actionTableUpdate.selectionRectangle.top,
      actionTableUpdate.selectionRectangle.right,
      actionTableUpdate.selectionRectangle.bottom,
    );
    _restoreTargetPlatform();
    expect(
      (
        host.updateRequests.length,
        host.geometryUpdates.length,
        geometryUpdate?.$1,
        updatedRectangle != initialRectangle,
      ),
      (1, 1, actionTableUpdate.sessionIdentifier, true),
    );
  });

  testWidgets('when native show is slow, it should serialize work and deliver the latest selection', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost(
      deferShowResponses: true,
      deferUpdateResponses: true,
    )..setUp();
    const text = 'Keep only the latest pending native selection';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await _showSelectionMenu(tester, find.text(text));
    final editableTextState = _editableTextState(tester);

    for (final extentOffset in <int>[8, 18, text.length]) {
      editableTextState.userUpdateTextEditingValue(
        editableTextState.textEditingValue.copyWith(
          selection: TextSelection(
            baseOffset: 0,
            extentOffset: extentOffset,
          ),
        ),
        SelectionChangedCause.drag,
      );
      await tester.pump();
    }
    final glyphHeights = editableTextState.getGlyphHeights();
    final expectedRectangle = TextSelectionToolbarAnchors.getSelectionRect(
      editableTextState.renderEditable,
      glyphHeights.startGlyphHeight,
      glyphHeights.endGlyphHeight,
      editableTextState.renderEditable.getEndpointsForSelection(
        editableTextState.textEditingValue.selection,
      ),
    );

    while (host.pendingResponseCount > 0) {
      host.completeNextResponse();
      await tester.pump();
    }
    final latestRequest = host.updateRequests.lastOrNull;

    _restoreTargetPlatform();
    expect(
      (
        host.showRequests.length,
        host.updateRequests.length,
        host.maxInFlightOperations,
        latestRequest == null
            ? null
            : Rect.fromLTRB(
                latestRequest.selectionRectangle.left,
                latestRequest.selectionRectangle.top,
                latestRequest.selectionRectangle.right,
                latestRequest.selectionRectangle.bottom,
              ),
      ),
      (1, 1, 1, expectedRectangle),
    );
  });

  testWidgets('when an empty macOS action table interrupts show, it should ignore the late accepted response', (
    tester,
  ) async {
    _setTargetPlatform(TargetPlatform.macOS);
    addTearDown(_restoreTargetPlatform);
    var clipboardWriteCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardWriteCount += 1;
        }
        return null;
      },
    );
    final host = _NativeMenuHost(deferShowResponses: true)..setUp();
    const text = 'Replace a pending macOS menu without reviving it';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await tester.tap(find.text(text));
    await tester.pump();
    final editableTextState = _editableTextState(tester);
    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: 7),
      ),
      SelectionChangedCause.keyboard,
    );
    editableTextState.showToolbar();
    await tester.pump();
    await tester.pump();
    final initialRequest = host.showRequests.single;
    final initialCopy = initialRequest.items.singleWhere((item) => item.label == 'Copy');

    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection.collapsed(offset: 7),
      ),
      SelectionChangedCause.keyboard,
    );
    await tester.pump();
    await tester.pump();

    const reopenedSelection = TextSelection(baseOffset: 8, extentOffset: 13);
    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(selection: reopenedSelection),
      SelectionChangedCause.keyboard,
    );
    editableTextState.showToolbar();
    await tester.pump();
    await tester.pump();
    final reopenedRequest = host.showRequests.last;
    host.completeLastResponse();
    await tester.pump();
    if (host.pendingResponseCount > 0) {
      host.completeNextResponse();
      await tester.pump();
    }
    await host.sendAction(
      sessionIdentifier: initialRequest.sessionIdentifier,
      actionIdentifier: initialCopy.identifier,
    );
    await tester.pump();

    _restoreTargetPlatform();
    expect(
      (
        host.hiddenSessions.singleOrNull,
        host.showRequests.length,
        reopenedRequest.sessionIdentifier != initialRequest.sessionIdentifier,
        host.pendingResponseCount,
        clipboardWriteCount,
        editableTextState.textEditingValue.selection,
      ),
      (initialRequest.sessionIdentifier, 2, true, 0, 0, reopenedSelection),
    );
  });

  testWidgets('when native show is deferred, it should keep the presented action generation callable', (
    tester,
  ) async {
    _setTargetPlatform(TargetPlatform.android);
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments! as Map<Object?, Object?>;
          copiedText = arguments['text']! as String;
        }
        return null;
      },
    );
    final host = _NativeMenuHost(deferShowResponses: true)..setUp();
    const text = 'Keep the presented native action callable';
    const selection = TextSelection(baseOffset: 0, extentOffset: 12);
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await tester.tap(find.text(text));
    await tester.pump();
    final editableTextState = _editableTextState(tester);
    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(selection: selection),
      SelectionChangedCause.keyboard,
    );
    editableTextState.showToolbar();
    await tester.pump();
    await tester.pump();
    final request = host.showRequests.single;
    final copy = request.items.singleWhere((item) => item.label == 'Copy');

    await host.sendAction(
      sessionIdentifier: request.sessionIdentifier,
      actionIdentifier: copy.identifier,
    );
    await tester.pump();
    host.completeNextResponse();
    await tester.pump();

    _restoreTargetPlatform();
    expect(
      (host.maxInFlightOperations, copiedText),
      (1, selection.textInside(text)),
    );
  });

  testWidgets('when native update is slow, it should conflate pending selection changes', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost(deferUpdateResponses: true)..setUp();
    const text = 'Conflate every intermediate native selection update';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await _showSelectionMenu(tester, find.text(text));
    final editableTextState = _editableTextState(tester);

    for (final extentOffset in <int>[8, 18, 28, text.length]) {
      editableTextState.userUpdateTextEditingValue(
        editableTextState.textEditingValue.copyWith(
          selection: TextSelection(
            baseOffset: 0,
            extentOffset: extentOffset,
          ),
        ),
        SelectionChangedCause.drag,
      );
      await tester.pump();
    }
    final glyphHeights = editableTextState.getGlyphHeights();
    final expectedRectangle = TextSelectionToolbarAnchors.getSelectionRect(
      editableTextState.renderEditable,
      glyphHeights.startGlyphHeight,
      glyphHeights.endGlyphHeight,
      editableTextState.renderEditable.getEndpointsForSelection(
        editableTextState.textEditingValue.selection,
      ),
    );

    while (host.pendingResponseCount > 0) {
      host.completeNextResponse();
      await tester.pump();
    }
    final latestRequest = host.updateRequests.last;

    _restoreTargetPlatform();
    expect(
      (
        host.showRequests.length,
        host.updateRequests.length,
        host.maxInFlightOperations,
        Rect.fromLTRB(
          latestRequest.selectionRectangle.left,
          latestRequest.selectionRectangle.top,
          latestRequest.selectionRectangle.right,
          latestRequest.selectionRectangle.bottom,
        ),
      ),
      (1, 2, 1, expectedRectangle),
    );
  });

  testWidgets('when geometry delivery is slow, it should conflate pending selection changes', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost(deferGeometryUpdateResponses: true)..setUp();
    const text = 'Conflate compact geometry while native delivery is slow';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await _showSelectionMenu(tester, find.text(text));
    final editableTextState = _editableTextState(tester);

    for (final extentOffset in <int>[8, 18, 28, text.length - 1]) {
      editableTextState.userUpdateTextEditingValue(
        editableTextState.textEditingValue.copyWith(
          selection: TextSelection(
            baseOffset: 0,
            extentOffset: extentOffset,
          ),
        ),
        SelectionChangedCause.keyboard,
      );
      await tester.pump();
    }
    final glyphHeights = editableTextState.getGlyphHeights();
    final expectedRectangle = TextSelectionToolbarAnchors.getSelectionRect(
      editableTextState.renderEditable,
      glyphHeights.startGlyphHeight,
      glyphHeights.endGlyphHeight,
      editableTextState.renderEditable.getEndpointsForSelection(
        editableTextState.textEditingValue.selection,
      ),
    );

    while (host.pendingResponseCount > 0) {
      host.completeNextResponse();
      await tester.pump();
    }
    final latestGeometry = host.geometryUpdates.lastOrNull?.$2;

    _restoreTargetPlatform();
    expect(
      (
        host.showRequests.length,
        host.updateRequests.length,
        host.geometryUpdates.length,
        host.maxInFlightOperations,
        latestGeometry == null
            ? null
            : Rect.fromLTRB(
                latestGeometry[0],
                latestGeometry[1],
                latestGeometry[2],
                latestGeometry[3],
              ),
      ),
      (1, 1, 2, 1, expectedRectangle),
    );
  });

  testWidgets('when selected content availability changes, it should refresh actions only at transitions', (
    tester,
  ) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost()..setUp();
    const text = 'word   tail';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await tester.tap(find.text(text));
    await tester.pump();
    final editableTextState = _editableTextState(tester);
    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: 4),
      ),
      SelectionChangedCause.keyboard,
    );
    editableTextState.showToolbar();
    await tester.pump();
    await tester.pump();
    final initialRequest = host.showRequests.single;

    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 4, extentOffset: 7),
      ),
      SelectionChangedCause.keyboard,
    );
    await tester.pump();
    await tester.pump();
    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 5, extentOffset: 7),
      ),
      SelectionChangedCause.keyboard,
    );
    await tester.pump();
    await tester.pump();
    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 7, extentOffset: text.length),
      ),
      SelectionChangedCause.keyboard,
    );
    await tester.pump();
    await tester.pump();

    _restoreTargetPlatform();
    expect(
      (
        initialRequest.items.any((item) => item.label == 'Share'),
        host.updateRequests.length,
        host.updateRequests.first.items.any((item) => item.label == 'Share'),
        host.updateRequests.last.items.any((item) => item.label == 'Share'),
        host.geometryUpdates.length,
      ),
      (true, 2, false, true, 1),
    );
  });

  testWidgets('when actions change during an update, it should keep the visible generation callable', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments! as Map<Object?, Object?>;
          copiedText = arguments['text']! as String;
        }
        return null;
      },
    );
    final host = _NativeMenuHost(deferUpdateResponses: true)..setUp();
    const text = 'Keep the old native action generation callable';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await _showSelectionMenu(tester, find.text(text));
    final initialRequest = host.showRequests.single;
    final oldCopy = initialRequest.items.singleWhere((item) => item.label == 'Copy');
    final editableTextState = _editableTextState(tester);

    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: text.length),
      ),
      SelectionChangedCause.keyboard,
    );
    await tester.pump();
    await tester.pump();
    final updatedRequest = host.updateRequests.single;
    final updatedIdentifiers = updatedRequest.items.map((item) => item.identifier).toSet();
    await host.sendAction(
      sessionIdentifier: initialRequest.sessionIdentifier,
      actionIdentifier: oldCopy.identifier,
    );
    await tester.pump();
    host.completeNextResponse();
    await tester.pump();

    _restoreTargetPlatform();
    expect(
      (updatedIdentifiers.contains(oldCopy.identifier), copiedText),
      (false, text),
    );
  });

  testWidgets('when an action update completes, it should discard the previous generation', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    addTearDown(_restoreTargetPlatform);
    var clipboardWriteCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardWriteCount += 1;
        }
        return null;
      },
    );
    final host = _NativeMenuHost()..setUp();
    const text = 'Discard the superseded native action generation';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await _showSelectionMenu(tester, find.text(text));
    final initialRequest = host.showRequests.single;
    final oldCopy = initialRequest.items.singleWhere((item) => item.label == 'Copy');
    final editableTextState = _editableTextState(tester);

    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: text.length),
      ),
      SelectionChangedCause.keyboard,
    );
    await tester.pump();
    await tester.pump();
    await host.sendAction(
      sessionIdentifier: initialRequest.sessionIdentifier,
      actionIdentifier: oldCopy.identifier,
    );
    await tester.pump();

    _restoreTargetPlatform();
    expect(clipboardWriteCount, 0);
  });

  testWidgets('when locale changes during an update, it should keep the visible built-in action callable', (
    tester,
  ) async {
    _setTargetPlatform(TargetPlatform.android);
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments! as Map<Object?, Object?>;
          copiedText = arguments['text']! as String;
        }
        return null;
      },
    );
    final host = _NativeMenuHost(deferUpdateResponses: true)..setUp();
    const text = 'Keep the localized native action generation callable';
    const localizationsDelegates = <LocalizationsDelegate<dynamic>>[
      _LocalizedMenuDelegate(),
      _LocalizedCupertinoDelegate(),
    ];
    const supportedLocales = <Locale>[Locale('en'), Locale('pt')];
    await tester.pumpWidget(
      _testApp(
        const NativeSelectableText(text),
        locale: const Locale('en'),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
      ),
    );
    await tester.tap(find.text(text));
    await tester.pump();
    final editableTextState = _editableTextState(tester);
    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection(
          baseOffset: 0,
          extentOffset: text.length,
        ),
      ),
      SelectionChangedCause.keyboard,
    );
    editableTextState.showToolbar();
    await tester.pump();
    await tester.pump();
    final initialRequest = host.showRequests.single;
    final oldCopy = initialRequest.items.singleWhere((item) => item.label == 'Copy');

    await tester.pumpWidget(
      _testApp(
        const NativeSelectableText(text),
        locale: const Locale('pt'),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: supportedLocales,
      ),
    );
    await tester.pump();
    final updatedRequest = host.updateRequests.single;
    await host.sendAction(
      sessionIdentifier: initialRequest.sessionIdentifier,
      actionIdentifier: oldCopy.identifier,
    );
    await tester.pump();
    host.completeNextResponse();
    await tester.pump();

    _restoreTargetPlatform();
    expect(
      (
        updatedRequest.items.map((item) => item.label).contains('Copiar texto'),
        copiedText,
      ),
      (true, text),
    );
  });

  testWidgets('when an old update completes after action dismissal, it should reopen the current session', (
    tester,
  ) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost(deferUpdateResponses: true)..setUp();
    const text = 'Ignore an old native update response';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await _showSelectionMenu(tester, find.text(text));
    final initialRequest = host.showRequests.single;
    final editableTextState = _editableTextState(tester);

    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: text.length),
      ),
      SelectionChangedCause.drag,
    );
    await tester.pump();
    await host.sendDismissed(
      sessionIdentifier: initialRequest.sessionIdentifier,
      actionInvoked: true,
    );
    await tester.pump();
    host.completeNextResponse();
    await tester.pump();
    await tester.pump();

    _restoreTargetPlatform();
    expect(
      (
        host.showRequests.length,
        host.showRequests.first.sessionIdentifier != host.showRequests.last.sessionIdentifier,
        find.text('Copy').evaluate().length,
      ),
      (2, true, 0),
    );
  });

  testWidgets('when a native update is rejected, it should preserve selection with the adaptive toolbar', (
    tester,
  ) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost()..setUp();
    const text = 'Reject this update';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await _showSelectionMenu(tester, find.text(text));
    host.acceptsUpdates = false;
    final editableTextState = _editableTextState(tester);

    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: text.length),
      ),
      SelectionChangedCause.keyboard,
    );
    await tester.pump();
    await tester.pump();

    _restoreTargetPlatform();
    expect(
      (
        host.updateRequests.length,
        find.text('Copy').evaluate().length,
        editableTextState.textEditingValue.selection,
      ),
      (1, 1, const TextSelection(baseOffset: 0, extentOffset: text.length)),
    );
  });

  testWidgets('when a rejected update is followed by native dismissal, it should preserve adaptive fallback', (
    tester,
  ) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost()..setUp();
    const text = 'Ignore late native dismissal after rejected update';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await _showSelectionMenu(tester, find.text(text));
    final request = host.showRequests.single;
    host.acceptsUpdates = false;
    final editableTextState = _editableTextState(tester);
    const fullSelection = TextSelection(baseOffset: 0, extentOffset: text.length);

    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(selection: fullSelection),
      SelectionChangedCause.keyboard,
    );
    await tester.pump();
    await tester.pump();
    await host.sendDismissed(
      sessionIdentifier: request.sessionIdentifier,
      actionInvoked: false,
    );
    await tester.pump();

    _restoreTargetPlatform();
    expect(
      (
        editableTextState.textEditingValue.selection,
        find.text('Copy').evaluate().length,
      ),
      (fullSelection, 1),
    );
  });

  testWidgets('when rejected geometry is followed by native dismissal, it should preserve adaptive fallback', (
    tester,
  ) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost()..setUp();
    const text = 'Ignore late native dismissal after rejected geometry';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await _showSelectionMenu(tester, find.text(text));
    final request = host.showRequests.single;
    final editableTextState = _editableTextState(tester);

    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(
        selection: const TextSelection(baseOffset: 0, extentOffset: 12),
      ),
      SelectionChangedCause.keyboard,
    );
    await tester.pump();
    await tester.pump();
    host.acceptsGeometryUpdates = false;
    const latestSelection = TextSelection(baseOffset: 2, extentOffset: 16);
    editableTextState.userUpdateTextEditingValue(
      editableTextState.textEditingValue.copyWith(selection: latestSelection),
      SelectionChangedCause.keyboard,
    );
    await tester.pump();
    await tester.pump();
    await host.sendDismissed(
      sessionIdentifier: request.sessionIdentifier,
      actionInvoked: false,
    );
    await tester.pump();

    _restoreTargetPlatform();
    expect(
      (
        host.geometryUpdates.length,
        editableTextState.textEditingValue.selection,
        find.text('Copy').evaluate().length,
      ),
      (1, latestSelection, 1),
    );
  });

  testWidgets('when a stale native action arrives, it should not affect the current selection', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost()..setUp();
    await tester.pumpWidget(_testApp(const NativeSelectableText('First selection', key: ValueKey('first'))));
    await _showSelectionMenu(tester, find.text('First selection'));
    final staleRequest = host.showRequests.single;
    final staleSelectAll = staleRequest.items.singleWhere((item) => item.label == 'Select all');

    await tester.pumpWidget(_testApp(const NativeSelectableText('Second selection words', key: ValueKey('second'))));
    await _showSelectionMenu(tester, find.text('Second selection words'));
    final selectionBeforeCallback = _editableTextState(tester).textEditingValue.selection;
    await host.sendAction(
      sessionIdentifier: staleRequest.sessionIdentifier,
      actionIdentifier: staleSelectAll.identifier,
    );
    await tester.pump();

    _restoreTargetPlatform();
    expect(_editableTextState(tester).textEditingValue.selection, selectionBeforeCallback);
  });

  testWidgets('when a stale native dismissal arrives, it should preserve the current selection', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final focusNode = FocusNode();
    final host = _NativeMenuHost()..setUp();
    await tester.pumpWidget(_testApp(const NativeSelectableText('Old session', key: ValueKey('old'))));
    await _showSelectionMenu(tester, find.text('Old session'));
    final staleSessionIdentifier = host.showRequests.single.sessionIdentifier;

    await tester.pumpWidget(
      _testApp(
        NativeSelectableText('Current session', key: const ValueKey('current'), focusNode: focusNode),
      ),
    );
    await _showSelectionMenu(tester, find.text('Current session'));
    final selectionBeforeDismissal = _editableTextState(tester).textEditingValue.selection;
    await host.sendDismissed(sessionIdentifier: staleSessionIdentifier, actionInvoked: false);
    await tester.pump();

    _restoreTargetPlatform();
    expect(
      (focusNode.hasFocus, _editableTextState(tester).textEditingValue.selection),
      (true, selectionBeforeDismissal),
    );
    focusNode.dispose();
  });

  testWidgets('when native dismissal is external, it should clear focus and selection', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final focusNode = FocusNode();
    final host = _NativeMenuHost()..setUp();
    await tester.pumpWidget(_testApp(NativeSelectableText('Dismissed selection', focusNode: focusNode)));
    await _showSelectionMenu(tester, find.text('Dismissed selection'));
    final sessionIdentifier = host.showRequests.single.sessionIdentifier;

    await host.sendDismissed(sessionIdentifier: sessionIdentifier, actionInvoked: false);
    await tester.pump();
    final selection = _editableTextState(tester).textEditingValue.selection;

    _restoreTargetPlatform();
    expect((focusNode.hasFocus, selection.isValid), (false, false));
    focusNode.dispose();
  });

  testWidgets('when native dismissal follows an action, it should preserve Flutter selection', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final focusNode = FocusNode();
    final host = _NativeMenuHost()..setUp();
    await tester.pumpWidget(_testApp(NativeSelectableText('Action selection', focusNode: focusNode)));
    await _showSelectionMenu(tester, find.text('Action selection'));
    final request = host.showRequests.single;
    final selectionBeforeDismissal = _editableTextState(tester).textEditingValue.selection;

    await host.sendDismissed(sessionIdentifier: request.sessionIdentifier, actionInvoked: true);
    await tester.pump();

    _restoreTargetPlatform();
    expect(
      (focusNode.hasFocus, _editableTextState(tester).textEditingValue.selection),
      (true, selectionBeforeDismissal),
    );
    focusNode.dispose();
  });

  testWidgets('when the retained bridge remounts, it should hide the old session and show a new one', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost()..setUp();
    const text = 'Remount this retained native menu bridge';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await _showSelectionMenu(tester, find.text(text));
    final firstSessionIdentifier = host.showRequests.single.sessionIdentifier;

    ContextMenuController.removeAny();
    await tester.pump();
    _editableTextState(tester).showToolbar();
    await tester.pump();
    await tester.pump();
    final secondSessionIdentifier = host.showRequests.last.sessionIdentifier;

    _restoreTargetPlatform();
    expect(
      (
        host.hiddenSessions.singleOrNull,
        host.showRequests.length,
        secondSessionIdentifier != firstSessionIdentifier,
      ),
      (firstSessionIdentifier, 2, true),
    );
  });

  testWidgets('when a native action keeps the toolbar open, it should reopen the native menu', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final host = _NativeMenuHost()..setUp();
    const text = 'Select all and continue';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await _showSelectionMenu(tester, find.text(text));
    final request = host.showRequests.single;
    final selectAll = request.items.singleWhere((item) => item.label == 'Select all');

    await host.sendAction(sessionIdentifier: request.sessionIdentifier, actionIdentifier: selectAll.identifier);
    await host.sendDismissed(sessionIdentifier: request.sessionIdentifier, actionInvoked: true);
    await tester.pump();
    await tester.pump();

    _restoreTargetPlatform();
    expect(
      (
        host.showRequests.length,
        find.text('Copy').evaluate().length,
        host.showRequests.first.sessionIdentifier != host.showRequests.last.sessionIdentifier,
      ),
      (2, 0, true),
    );
  });

  testWidgets('when an outside interaction occurs, it should clear focus and selection', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final focusNode = FocusNode();
    _NativeMenuHost().setUp();
    await tester.pumpWidget(
      _testApp(
        NativeSelectableText('Outside selection', focusNode: focusNode),
        outside: const TextButton(onPressed: null, child: Text('Outside target')),
      ),
    );
    await _showSelectionMenu(tester, find.text('Outside selection'));

    await tester.tap(find.text('Outside target'));
    await tester.pump();
    final selection = _editableTextState(tester).textEditingValue.selection;

    _restoreTargetPlatform();
    expect((focusNode.hasFocus, selection.isValid), (false, false));
    focusNode.dispose();
  });

  testWidgets('when an outside interaction clears selection, it should preserve editable state', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    _NativeMenuHost().setUp();
    await tester.pumpWidget(
      _testApp(
        const NativeSelectableText('Preserve state after dismissal'),
        outside: const TextButton(
          onPressed: null,
          child: Text('Outside state target'),
        ),
      ),
    );
    await _showSelectionMenu(
      tester,
      find.text('Preserve state after dismissal'),
    );
    final editableTextStateBeforeDismissal = _editableTextState(tester);

    await tester.tap(find.text('Outside state target'));
    await tester.pump();
    final editableTextStateAfterDismissal = _editableTextState(tester);

    _restoreTargetPlatform();
    expect(
      editableTextStateAfterDismissal,
      same(editableTextStateBeforeDismissal),
    );
  });

  testWidgets('when focus moves to another text field, it should clear the old selection', (tester) async {
    _setTargetPlatform(TargetPlatform.android);
    final focusNode = FocusNode();
    _NativeMenuHost().setUp();
    await tester.pumpWidget(
      _testApp(
        NativeSelectableText('Focus transfer selection', focusNode: focusNode),
        outside: const TextField(key: ValueKey('other-field')),
      ),
    );
    await _showSelectionMenu(tester, find.text('Focus transfer selection'));

    await tester.tap(find.byKey(const ValueKey('other-field')));
    await tester.pump();
    final selection = _editableTextState(tester).textEditingValue.selection;

    _restoreTargetPlatform();
    expect((focusNode.hasFocus, selection.isValid), (false, false));
    focusNode.dispose();
  });

  testWidgets('when an adaptive toolbar action is tapped, it should not be treated as outside', (tester) async {
    _setTargetPlatform(TargetPlatform.fuchsia);
    const text = 'Toolbar action regression';
    await tester.pumpWidget(_testApp(const NativeSelectableText(text)));
    await _showSelectionMenu(tester, find.text(text));

    await tester.tap(find.text('Select all'));
    await tester.pump();

    _restoreTargetPlatform();
    expect(
      _editableTextState(tester).textEditingValue.selection,
      const TextSelection(baseOffset: 0, extentOffset: text.length),
    );
  });
}
