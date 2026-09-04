import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pigeon/native_selectable_text.g.dart';

part '_native_selectable_text_menu_bridge.dart';
part '_native_selectable_text_browser_context_menu.dart';
part '_native_selectable_text_menu_coordinator.dart';

/// Displays selectable text with the operating system's selection menu.
///
/// The text follows Flutter's ordinary selection, layout, accessibility, and
/// magnifier behavior. Android, iOS, Linux, macOS, and Windows present the
/// available selection commands in a system-rendered menu. Other platforms,
/// unsupported operating-system versions, and unavailable native hosts use
/// Flutter's adaptive selection toolbar instead.
///
/// Use [SelectableText] when a Flutter-rendered or fully custom context menu is
/// preferred.
///
/// See the
/// [NativeSelectableText guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/native_selectable_text.md)
/// for platform behavior and usage guidance.
class NativeSelectableText extends StatefulWidget {
  /// Creates selectable plain text with a native selection menu when available.
  const NativeSelectableText(
    String this.data, {
    super.key,
    this.focusNode,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.textScaler,
    this.showCursor = false,
    this.autofocus = false,
    this.minLines,
    this.maxLines,
    this.cursorWidth = 2,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.selectionColor,
    this.selectionHeightStyle,
    this.selectionWidthStyle,
    this.dragStartBehavior = DragStartBehavior.start,
    this.enableInteractiveSelection = true,
    this.selectionControls,
    this.onTap,
    this.scrollPhysics,
    this.scrollBehavior,
    this.semanticsLabel,
    this.textHeightBehavior,
    this.textWidthBasis,
    this.onSelectionChanged,
    this.magnifierConfiguration,
  }) : assert(
         maxLines == null || maxLines > 0,
         'maxLines must be greater than zero',
       ),
       assert(
         minLines == null || minLines > 0,
         'minLines must be greater than zero',
       ),
       assert(
         maxLines == null || minLines == null || maxLines >= minLines,
         "minLines can't be greater than maxLines",
       ),
       assert(
         selectionControls == null || selectionControls is TextSelectionHandleControls,
         'selectionControls must leave toolbar presentation to contextMenuBuilder',
       ),
       textSpan = null;

  /// Creates selectable rich text with a native selection menu when available.
  ///
  /// Every entry in [TextSpan.children] must also be a [TextSpan].
  const NativeSelectableText.rich(
    TextSpan this.textSpan, {
    super.key,
    this.focusNode,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.textScaler,
    this.showCursor = false,
    this.autofocus = false,
    this.minLines,
    this.maxLines,
    this.cursorWidth = 2,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorColor,
    this.selectionColor,
    this.selectionHeightStyle,
    this.selectionWidthStyle,
    this.dragStartBehavior = DragStartBehavior.start,
    this.enableInteractiveSelection = true,
    this.selectionControls,
    this.onTap,
    this.scrollPhysics,
    this.scrollBehavior,
    this.semanticsLabel,
    this.textHeightBehavior,
    this.textWidthBasis,
    this.onSelectionChanged,
    this.magnifierConfiguration,
  }) : assert(
         maxLines == null || maxLines > 0,
         'maxLines must be greater than zero',
       ),
       assert(
         minLines == null || minLines > 0,
         'minLines must be greater than zero',
       ),
       assert(
         maxLines == null || minLines == null || maxLines >= minLines,
         "minLines can't be greater than maxLines",
       ),
       assert(
         selectionControls == null || selectionControls is TextSelectionHandleControls,
         'selectionControls must leave toolbar presentation to contextMenuBuilder',
       ),
       data = null;

  /// The plain text displayed by the default constructor.
  final String? data;

  /// The styled text displayed by [NativeSelectableText.rich].
  final TextSpan? textSpan;

  /// The focus node used for selection focus.
  final FocusNode? focusNode;

  /// The text style merged with the surrounding default text style.
  final TextStyle? style;

  /// The strut used to control minimum line metrics.
  final StrutStyle? strutStyle;

  /// How each line is aligned horizontally.
  final TextAlign? textAlign;

  /// The direction used to order and align the text.
  final TextDirection? textDirection;

  /// How inherited text scaling is overridden.
  final TextScaler? textScaler;

  /// Whether a cursor is painted for the current selection.
  final bool showCursor;

  /// Whether the text requests focus when first mounted.
  final bool autofocus;

  /// The minimum number of lines occupied by the text.
  final int? minLines;

  /// The maximum number of lines displayed before scrolling.
  final int? maxLines;

  /// The cursor width in logical pixels.
  final double cursorWidth;

  /// The cursor height, or the text line height when omitted.
  final double? cursorHeight;

  /// The radius applied to the cursor corners.
  final Radius? cursorRadius;

  /// The cursor color.
  final Color? cursorColor;

  /// The color painted behind selected text.
  final Color? selectionColor;

  /// How selection highlights cover line height.
  final ui.BoxHeightStyle? selectionHeightStyle;

  /// How selection highlights cover line width.
  final ui.BoxWidthStyle? selectionWidthStyle;

  /// How drag gestures choose their initial position.
  final DragStartBehavior dragStartBehavior;

  /// Whether pointer gestures can change the selection.
  final bool enableInteractiveSelection;

  /// The platform controls used to paint selection handles.
  ///
  /// Controls that also replace the toolbar are unsupported because this
  /// widget owns menu presentation.
  final TextSelectionControls? selectionControls;

  /// Called when the text is tapped.
  final GestureTapCallback? onTap;

  /// The physics used when multiline text scrolls internally.
  final ScrollPhysics? scrollPhysics;

  /// The behavior used by the internal scrollable.
  final ScrollBehavior? scrollBehavior;

  /// An alternative label announced by accessibility services.
  final String? semanticsLabel;

  /// Fine-grained behavior for text height above and below glyphs.
  final TextHeightBehavior? textHeightBehavior;

  /// How the paragraph chooses the width used for line measurement.
  final TextWidthBasis? textWidthBasis;

  /// Called whenever the selected range changes.
  final SelectionChangedCallback? onSelectionChanged;

  /// The magnifier configuration used during selection gestures.
  final TextMagnifierConfiguration? magnifierConfiguration;

  @override
  State<NativeSelectableText> createState() => _NativeSelectableTextState();
}

class _NativeSelectableTextState extends State<NativeSelectableText> {
  final Object _browserContextMenuLease = Object();
  late final Map<Type, Action<Intent>> _tapOutsideActions;
  EditableTextState? _editableTextState;
  GlobalKey<_NativeSelectableTextMenuBridgeState>? _menuBridgeKey;
  _NativeSelectableTextMenuBridge? _menuBridge;
  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  late bool _selectionClearedAfterFocusLoss;
  Timer? _webContextMenuPreparationTimer;
  bool _holdsBrowserContextMenuLease = false;

  @override
  void initState() {
    super.initState();
    _tapOutsideActions = <Type, Action<Intent>>{
      EditableTextTapOutsideIntent: CallbackAction<EditableTextTapOutsideIntent>(
        onInvoke: _handleTapOutsideIntent,
      ),
    };
    _setFocusNode(widget.focusNode);
  }

  @override
  void didUpdateWidget(NativeSelectableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) {
      return;
    }
    _focusNode.removeListener(_handleFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    _setFocusNode(widget.focusNode);
  }

  @override
  void dispose() {
    _webContextMenuPreparationTimer?.cancel();
    _releaseBrowserContextMenuLease();
    _focusNode.removeListener(_handleFocusChanged);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _setFocusNode(FocusNode? focusNode) {
    _ownsFocusNode = focusNode == null;
    _focusNode = focusNode ?? FocusNode(skipTraversal: true);
    _selectionClearedAfterFocusLoss = !_focusNode.hasFocus;
    _focusNode.addListener(_handleFocusChanged);
  }

  void _clearSelection() {
    if (!mounted || _selectionClearedAfterFocusLoss) {
      return;
    }
    _focusNode.unfocus();
    if (_selectionClearedAfterFocusLoss) {
      return;
    }
    _selectionClearedAfterFocusLoss = true;
    _resetSelection();
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus) {
      _selectionClearedAfterFocusLoss = false;
      return;
    }
    if (!mounted || _selectionClearedAfterFocusLoss) {
      return;
    }
    _selectionClearedAfterFocusLoss = true;
    _resetSelection();
  }

  void _resetSelection() {
    _webContextMenuPreparationTimer?.cancel();
    _releaseBrowserContextMenuLease();
    final editableTextState = _editableTextState;
    _editableTextState = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _focusNode.hasFocus || editableTextState == null || !editableTextState.mounted) {
        return;
      }
      final editingValue = editableTextState.textEditingValue;
      if (editingValue.selection.isValid) {
        editableTextState.userUpdateTextEditingValue(
          editingValue.copyWith(
            selection: const TextSelection.collapsed(offset: -1),
          ),
          SelectionChangedCause.keyboard,
        );
      }
    });
    ContextMenuController.removeAny();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!kIsWeb || !widget.enableInteractiveSelection) {
      return;
    }
    _webContextMenuPreparationTimer?.cancel();
    if (event.buttons & kSecondaryMouseButton != 0) {
      _acquireBrowserContextMenuLease();
      return;
    }
    _webContextMenuPreparationTimer = Timer(
      kLongPressTimeout - const Duration(milliseconds: 50),
      _acquireBrowserContextMenuLease,
    );
  }

  void _handlePointerEnded(PointerEvent _) {
    _webContextMenuPreparationTimer?.cancel();
    _webContextMenuPreparationTimer = null;
    _releaseBrowserContextMenuLease();
  }

  void _acquireBrowserContextMenuLease() {
    _webContextMenuPreparationTimer = null;
    if (!mounted || _holdsBrowserContextMenuLease) {
      return;
    }
    _holdsBrowserContextMenuLease = true;
    _NativeSelectableTextBrowserContextMenu.instance.acquire(
      _browserContextMenuLease,
    );
  }

  void _releaseBrowserContextMenuLease() {
    if (!_holdsBrowserContextMenuLease) {
      return;
    }
    _holdsBrowserContextMenuLease = false;
    _NativeSelectableTextBrowserContextMenu.instance.release(
      _browserContextMenuLease,
    );
  }

  Object? _handleTapOutsideIntent(EditableTextTapOutsideIntent _) {
    _clearSelection();
    return null;
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    _editableTextState = editableTextState;
    if (!_supportsNativeMenu(context)) {
      return AdaptiveTextSelectionToolbar.editableText(
        editableTextState: editableTextState,
      );
    }
    var menuBridge = _menuBridge;
    if (menuBridge == null || !identical(menuBridge.editableTextState, editableTextState)) {
      final menuBridgeKey = GlobalKey<_NativeSelectableTextMenuBridgeState>();
      _menuBridgeKey = menuBridgeKey;
      menuBridge = _NativeSelectableTextMenuBridge(
        key: menuBridgeKey,
        editableTextState: editableTextState,
        onExternalDismissed: _clearSelection,
      );
      _menuBridge = menuBridge;
    } else {
      final menuBridgeState = _menuBridgeKey?.currentState;
      if (menuBridgeState?.usesAdaptiveToolbar ?? false) {
        menuBridge = _NativeSelectableTextMenuBridge(
          key: _menuBridgeKey,
          editableTextState: editableTextState,
          onExternalDismissed: _clearSelection,
        );
        _menuBridge = menuBridge;
      } else {
        menuBridgeState?.requestPresentation();
      }
    }
    return menuBridge;
  }

  bool _supportsNativeMenu(BuildContext context) {
    if (kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.linux || TargetPlatform.macOS || TargetPlatform.windows => true,
      TargetPlatform.iOS => MediaQuery.maybeSupportsShowingSystemContextMenu(context) ?? false,
      TargetPlatform.fuchsia => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final selectableText = widget.textSpan == null
        ? SelectableText(
            widget.data!,
            focusNode: _focusNode,
            style: widget.style,
            strutStyle: widget.strutStyle,
            textAlign: widget.textAlign,
            textDirection: widget.textDirection,
            textScaler: widget.textScaler,
            showCursor: widget.showCursor,
            autofocus: widget.autofocus,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            cursorWidth: widget.cursorWidth,
            cursorHeight: widget.cursorHeight,
            cursorRadius: widget.cursorRadius,
            cursorColor: widget.cursorColor,
            selectionColor: widget.selectionColor,
            selectionHeightStyle: widget.selectionHeightStyle,
            selectionWidthStyle: widget.selectionWidthStyle,
            dragStartBehavior: widget.dragStartBehavior,
            enableInteractiveSelection: widget.enableInteractiveSelection,
            selectionControls: widget.selectionControls,
            onTap: widget.onTap,
            scrollPhysics: widget.scrollPhysics,
            scrollBehavior: widget.scrollBehavior,
            semanticsLabel: widget.semanticsLabel,
            textHeightBehavior: widget.textHeightBehavior,
            textWidthBasis: widget.textWidthBasis,
            onSelectionChanged: widget.onSelectionChanged,
            contextMenuBuilder: _buildContextMenu,
            magnifierConfiguration: widget.magnifierConfiguration,
          )
        : SelectableText.rich(
            widget.textSpan!,
            focusNode: _focusNode,
            style: widget.style,
            strutStyle: widget.strutStyle,
            textAlign: widget.textAlign,
            textDirection: widget.textDirection,
            textScaler: widget.textScaler,
            showCursor: widget.showCursor,
            autofocus: widget.autofocus,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            cursorWidth: widget.cursorWidth,
            cursorHeight: widget.cursorHeight,
            cursorRadius: widget.cursorRadius,
            cursorColor: widget.cursorColor,
            selectionColor: widget.selectionColor,
            selectionHeightStyle: widget.selectionHeightStyle,
            selectionWidthStyle: widget.selectionWidthStyle,
            dragStartBehavior: widget.dragStartBehavior,
            enableInteractiveSelection: widget.enableInteractiveSelection,
            selectionControls: widget.selectionControls,
            onTap: widget.onTap,
            scrollPhysics: widget.scrollPhysics,
            scrollBehavior: widget.scrollBehavior,
            semanticsLabel: widget.semanticsLabel,
            textHeightBehavior: widget.textHeightBehavior,
            textWidthBasis: widget.textWidthBasis,
            onSelectionChanged: widget.onSelectionChanged,
            contextMenuBuilder: _buildContextMenu,
            magnifierConfiguration: widget.magnifierConfiguration,
          );

    final outsideAwareSelectableText = Actions(
      actions: _tapOutsideActions,
      child: selectableText,
    );
    if (!kIsWeb) {
      return outsideAwareSelectableText;
    }
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerEnded,
      onPointerCancel: _handlePointerEnded,
      child: outsideAwareSelectableText,
    );
  }
}
