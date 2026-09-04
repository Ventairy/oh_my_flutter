part of 'native_selectable_text.dart';

final class _NativeSelectableTextMenuBridge extends StatefulWidget {
  const _NativeSelectableTextMenuBridge({
    required this.editableTextState,
    required this.onExternalDismissed,
    super.key,
  });

  final EditableTextState editableTextState;
  final VoidCallback onExternalDismissed;

  @override
  State<_NativeSelectableTextMenuBridge> createState() => _NativeSelectableTextMenuBridgeState();
}

class _NativeSelectableTextMenuBridgeState extends State<_NativeSelectableTextMenuBridge> {
  static const int _validSelectionAvailability = 1 << 0;
  static const int _collapsedSelectionAvailability = 1 << 1;
  static const int _fullSelectionAvailability = 1 << 2;
  static const int _nonWhitespaceSelectionAvailability = 1 << 3;

  final _NativeSelectableTextMenuCoordinator _coordinator = _NativeSelectableTextMenuCoordinator.instance;
  final List<ContextMenuButtonItem> _candidateButtonItems = <ContextMenuButtonItem>[];
  final List<String> _candidateLabels = <String>[];
  final Float64List _geometryMessage = Float64List(6);
  late final void Function(Duration) _postFrameCallback;
  late int _sessionIdentifier;
  Map<int, VoidCallback> _currentTableActions = const <int, VoidCallback>{};
  Map<int, VoidCallback> _pendingActions = const <int, VoidCallback>{};
  List<String> _tableLabels = const <String>[];
  List<ContextMenuButtonType> _tableTypes = const <ContextMenuButtonType>[];
  List<NativeSelectableTextMenuItemMessage> _tableItems = const <NativeSelectableTextMenuItemMessage>[];
  List<NativeSelectableTextMenuItemMessage> _pendingItems = const <NativeSelectableTextMenuItemMessage>[];
  int _nextActionIdentifier = 1;
  int _tableRevision = 0;
  int _pendingTableRevision = 0;
  int _lastPresentedTableRevision = -1;
  TextSelection? _lastPreparedSelection;
  String? _lastPreparedText;
  int? _lastPreparedActionAvailability;
  double _pendingLeft = 0;
  double _pendingTop = 0;
  double _pendingRight = 0;
  double _pendingBottom = 0;
  double _pendingAnchorDx = 0;
  double _pendingAnchorDy = 0;
  double _lastPresentedLeft = 0;
  double _lastPresentedTop = 0;
  double _lastPresentedRight = 0;
  double _lastPresentedBottom = 0;
  double _lastPresentedAnchorDx = 0;
  double _lastPresentedAnchorDy = 0;
  bool _actionTableRefreshNeeded = true;
  bool _preparationNeeded = false;
  bool _preparationScheduled = false;
  bool _presentationPending = false;
  bool _presentationInProgress = false;
  bool _shown = false;
  bool _toolbarHidePending = false;
  bool _useAdaptiveToolbar = false;

  bool get usesAdaptiveToolbar => _useAdaptiveToolbar;

  @override
  void initState() {
    super.initState();
    _postFrameCallback = _handlePostFrame;
    _sessionIdentifier = _coordinator.createSessionIdentifier();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actionTableRefreshNeeded = true;
  }

  @override
  void dispose() {
    _coordinator.hide(_sessionIdentifier);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_useAdaptiveToolbar) {
      return AdaptiveTextSelectionToolbar.editableText(
        editableTextState: widget.editableTextState,
      );
    }

    requestPresentation();
    return const SizedBox.shrink();
  }

  void requestPresentation() {
    if (!mounted || _useAdaptiveToolbar) {
      return;
    }
    if (!_shown && !_presentationInProgress) {
      _preparePresentation();
    } else {
      _preparationNeeded = true;
    }
    _schedulePreparation();
  }

  void _schedulePreparation() {
    if (_preparationScheduled) {
      return;
    }
    _preparationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback(_postFrameCallback);
  }

  void _handlePostFrame(Duration _) {
    _preparationScheduled = false;
    if (!mounted || _useAdaptiveToolbar) {
      return;
    }
    if (_preparationNeeded) {
      _preparationNeeded = false;
      _preparePresentation();
    }
    if (_toolbarHidePending) {
      _toolbarHidePending = false;
      _hideToolbarWithoutActions();
      return;
    }
    if (_presentationPending) {
      unawaited(_drainPresentations());
    }
  }

  void _preparePresentation() {
    final editableTextState = widget.editableTextState;
    if (!editableTextState.mounted) {
      return;
    }
    final renderEditable = editableTextState.renderEditable;
    if (!renderEditable.attached || renderEditable.text == null) {
      return;
    }
    final editingValue = editableTextState.textEditingValue;
    if (_shouldRefreshActionTable(editingValue)) {
      _refreshActionTable(editableTextState);
    }
    if (_tableItems.isEmpty) {
      return;
    }

    final glyphHeights = editableTextState.getGlyphHeights();
    final selectionEndpoints = renderEditable.getEndpointsForSelection(
      editingValue.selection,
    );
    final transform = renderEditable.getTransformTo(null);
    final editingRegion = Rect.fromPoints(
      MatrixUtils.transformPoint(transform, Offset.zero),
      MatrixUtils.transformPoint(
        transform,
        renderEditable.size.bottomRight(Offset.zero),
      ),
    );
    final selectionRectangle = _selectionRectangle(
      editingRegion: editingRegion,
      selectionEndpoints: selectionEndpoints,
      startGlyphHeight: glyphHeights.startGlyphHeight,
      endGlyphHeight: glyphHeights.endGlyphHeight,
    );
    final primaryAnchor = _primaryAnchor(
      editingRegion: editingRegion,
      selectionRectangle: selectionRectangle,
      secondaryTapPosition: renderEditable.lastSecondaryTapDownPosition,
    );
    _pendingLeft = selectionRectangle.left;
    _pendingTop = selectionRectangle.top;
    _pendingRight = selectionRectangle.right;
    _pendingBottom = selectionRectangle.bottom;
    _pendingAnchorDx = primaryAnchor.dx;
    _pendingAnchorDy = primaryAnchor.dy;
    _pendingTableRevision = _tableRevision;
    _pendingItems = _tableItems;
    _pendingActions = _currentTableActions;
    _presentationPending = true;
  }

  bool _shouldRefreshActionTable(TextEditingValue editingValue) {
    final previousSelection = _lastPreparedSelection;
    final previousText = _lastPreparedText;
    final previousActionAvailability = _lastPreparedActionAvailability;
    final selection = editingValue.selection;
    final text = editingValue.text;
    final samePreparedValue = previousSelection == selection && previousText == text;
    final actionAvailability = samePreparedValue && previousActionAvailability != null
        ? previousActionAvailability
        : _actionAvailability(selection: selection, text: text);
    final refresh =
        _actionTableRefreshNeeded ||
        previousSelection == null ||
        previousText != text ||
        previousActionAvailability != actionAvailability;
    _actionTableRefreshNeeded = false;
    _lastPreparedSelection = selection;
    _lastPreparedText = text;
    _lastPreparedActionAvailability = actionAvailability;
    return refresh;
  }

  int _actionAvailability({
    required TextSelection selection,
    required String text,
  }) {
    final isValid = selection.isValid;
    final isCollapsed = selection.isCollapsed;
    var availability = 0;
    if (isValid) {
      availability |= _validSelectionAvailability;
    }
    if (isCollapsed) {
      availability |= _collapsedSelectionAvailability;
    }
    if (!isValid || isCollapsed) {
      return availability;
    }
    if (selection.start == 0 && selection.end == text.length) {
      availability |= _fullSelectionAvailability;
    }
    if (selection.textInside(text).trim().isNotEmpty) {
      availability |= _nonWhitespaceSelectionAvailability;
    }
    return availability;
  }

  void _refreshActionTable(EditableTextState editableTextState) {
    final buttonItems = editableTextState.contextMenuButtonItems;
    _candidateButtonItems.clear();
    _candidateLabels.clear();
    for (final buttonItem in buttonItems) {
      final onPressed = buttonItem.onPressed;
      final label = AdaptiveTextSelectionToolbar.getButtonLabel(
        context,
        buttonItem,
      );
      if (onPressed == null || label.isEmpty) {
        continue;
      }
      _candidateButtonItems.add(buttonItem);
      _candidateLabels.add(label);
    }
    if (_candidateButtonItems.isEmpty) {
      _clearActionTable();
      _closeMenuWithoutActions();
      return;
    }
    _toolbarHidePending = false;
    if (!_sameActionTable()) {
      _replaceActionTable();
    }
    _candidateButtonItems.clear();
    _candidateLabels.clear();
  }

  void _clearActionTable() {
    if (_tableItems.isEmpty) {
      return;
    }
    _tableLabels = const <String>[];
    _tableTypes = const <ContextMenuButtonType>[];
    _tableItems = const <NativeSelectableTextMenuItemMessage>[];
    _currentTableActions = const <int, VoidCallback>{};
    _tableRevision += 1;
  }

  void _closeMenuWithoutActions() {
    final sessionIdentifier = _sessionIdentifier;
    _coordinator.hide(sessionIdentifier);
    _sessionIdentifier = _coordinator.createSessionIdentifier();
    _pendingTableRevision = _tableRevision;
    _pendingItems = const <NativeSelectableTextMenuItemMessage>[];
    _pendingActions = const <int, VoidCallback>{};
    _presentationPending = false;
    _shown = false;
    _lastPresentedTableRevision = -1;
    _toolbarHidePending = true;
  }

  void _hideToolbarWithoutActions() {
    final editableTextState = widget.editableTextState;
    if (_tableItems.isNotEmpty || !editableTextState.mounted) {
      return;
    }
    editableTextState.hideToolbar(false);
  }

  bool _sameActionTable() {
    if (_candidateButtonItems.length != _tableLabels.length) {
      return false;
    }
    for (var index = 0; index < _candidateButtonItems.length; index += 1) {
      if (_candidateLabels[index] != _tableLabels[index] || _candidateButtonItems[index].type != _tableTypes[index]) {
        return false;
      }
    }
    return true;
  }

  void _replaceActionTable() {
    final types = <ContextMenuButtonType>[];
    final items = <NativeSelectableTextMenuItemMessage>[];
    final actions = <int, VoidCallback>{};
    for (var index = 0; index < _candidateButtonItems.length; index += 1) {
      final type = _candidateButtonItems[index].type;
      final label = _candidateLabels[index];
      final identifier = _nextActionIdentifier++;
      var occurrence = 0;
      for (var previousIndex = 0; previousIndex < index; previousIndex += 1) {
        if (_candidateButtonItems[previousIndex].type == type &&
            (type != ContextMenuButtonType.custom || _candidateLabels[previousIndex] == label)) {
          occurrence += 1;
        }
      }
      void invokeAction() {
        _invokeCurrentAction(
          type: type,
          label: label,
          occurrence: occurrence,
        );
      }

      types.add(type);
      items.add(
        NativeSelectableTextMenuItemMessage(
          identifier: identifier,
          label: label,
        ),
      );
      actions[identifier] = invokeAction;
    }
    _tableLabels = List<String>.unmodifiable(_candidateLabels);
    _tableTypes = List<ContextMenuButtonType>.unmodifiable(types);
    _tableItems = List<NativeSelectableTextMenuItemMessage>.unmodifiable(items);
    _currentTableActions = Map<int, VoidCallback>.unmodifiable(actions);
    _tableRevision += 1;
  }

  void _invokeCurrentAction({
    required ContextMenuButtonType type,
    required String label,
    required int occurrence,
  }) {
    final editableTextState = widget.editableTextState;
    if (!mounted || !editableTextState.mounted) {
      return;
    }
    var matchingOccurrence = 0;
    for (final buttonItem in editableTextState.contextMenuButtonItems) {
      final onPressed = buttonItem.onPressed;
      if (onPressed == null || buttonItem.type != type) {
        continue;
      }
      if (type == ContextMenuButtonType.custom) {
        final currentLabel = AdaptiveTextSelectionToolbar.getButtonLabel(
          context,
          buttonItem,
        );
        if (currentLabel != label) {
          continue;
        }
      }
      if (matchingOccurrence == occurrence) {
        onPressed();
        return;
      }
      matchingOccurrence += 1;
    }
  }

  Future<void> _drainPresentations() async {
    if (_presentationInProgress) {
      return;
    }
    _presentationInProgress = true;
    try {
      while (mounted && !_useAdaptiveToolbar) {
        if (!_presentationPending) {
          return;
        }
        final sessionIdentifier = _sessionIdentifier;
        final tableRevision = _pendingTableRevision;
        final items = _pendingItems;
        final actions = _pendingActions;
        final left = _pendingLeft;
        final top = _pendingTop;
        final right = _pendingRight;
        final bottom = _pendingBottom;
        final anchorDx = _pendingAnchorDx;
        final anchorDy = _pendingAnchorDy;
        _presentationPending = false;

        final sameTable = _shown && tableRevision == _lastPresentedTableRevision;
        if (sameTable &&
            _sameGeometry(
              left: left,
              top: top,
              right: right,
              bottom: bottom,
              anchorDx: anchorDx,
              anchorDy: anchorDy,
            )) {
          continue;
        }

        final bool accepted;
        if (!_shown) {
          accepted = await _coordinator.show(
            request: _createRequest(
              sessionIdentifier: sessionIdentifier,
              items: items,
              left: left,
              top: top,
              right: right,
              bottom: bottom,
              anchorDx: anchorDx,
              anchorDy: anchorDy,
            ),
            actions: actions,
            onExternalDismissed: _handleExternalDismissal,
            onActionDismissed: _handleActionDismissal,
          );
        } else if (!sameTable) {
          accepted = await _coordinator.update(
            request: _createRequest(
              sessionIdentifier: sessionIdentifier,
              items: items,
              left: left,
              top: top,
              right: right,
              bottom: bottom,
              anchorDx: anchorDx,
              anchorDy: anchorDy,
            ),
            actions: actions,
          );
        } else {
          _geometryMessage
            ..[0] = left
            ..[1] = top
            ..[2] = right
            ..[3] = bottom
            ..[4] = anchorDx
            ..[5] = anchorDy;
          accepted = await _coordinator.updateGeometry(
            sessionIdentifier: sessionIdentifier,
            geometry: _geometryMessage,
          );
        }
        if (!mounted || sessionIdentifier != _sessionIdentifier) {
          return;
        }
        if (!accepted) {
          _presentationPending = false;
          setState(() => _useAdaptiveToolbar = true);
          return;
        }
        _shown = true;
        _lastPresentedTableRevision = tableRevision;
        _recordPresentedGeometry(
          left: left,
          top: top,
          right: right,
          bottom: bottom,
          anchorDx: anchorDx,
          anchorDy: anchorDy,
        );
      }
    } finally {
      _presentationInProgress = false;
      if (mounted && !_useAdaptiveToolbar && _presentationPending) {
        unawaited(_drainPresentations());
      }
    }
  }

  NativeSelectableTextMenuRequestMessage _createRequest({
    required int sessionIdentifier,
    required List<NativeSelectableTextMenuItemMessage> items,
    required double left,
    required double top,
    required double right,
    required double bottom,
    required double anchorDx,
    required double anchorDy,
  }) {
    return NativeSelectableTextMenuRequestMessage(
      sessionIdentifier: sessionIdentifier,
      selectionRectangle: NativeSelectableTextRectangleMessage(
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      ),
      primaryAnchor: NativeSelectableTextPointMessage(
        dx: anchorDx,
        dy: anchorDy,
      ),
      items: items,
    );
  }

  bool _sameGeometry({
    required double left,
    required double top,
    required double right,
    required double bottom,
    required double anchorDx,
    required double anchorDy,
  }) {
    return left == _lastPresentedLeft &&
        top == _lastPresentedTop &&
        right == _lastPresentedRight &&
        bottom == _lastPresentedBottom &&
        anchorDx == _lastPresentedAnchorDx &&
        anchorDy == _lastPresentedAnchorDy;
  }

  void _recordPresentedGeometry({
    required double left,
    required double top,
    required double right,
    required double bottom,
    required double anchorDx,
    required double anchorDy,
  }) {
    _lastPresentedLeft = left;
    _lastPresentedTop = top;
    _lastPresentedRight = right;
    _lastPresentedBottom = bottom;
    _lastPresentedAnchorDx = anchorDx;
    _lastPresentedAnchorDy = anchorDy;
  }

  Rect _selectionRectangle({
    required Rect editingRegion,
    required List<TextSelectionPoint> selectionEndpoints,
    required double startGlyphHeight,
    required double endGlyphHeight,
  }) {
    if (editingRegion.left.isNaN ||
        editingRegion.top.isNaN ||
        editingRegion.right.isNaN ||
        editingRegion.bottom.isNaN) {
      return Rect.zero;
    }

    final isMultiline = selectionEndpoints.last.point.dy - selectionEndpoints.first.point.dy > endGlyphHeight / 2;
    return Rect.fromLTRB(
      isMultiline ? editingRegion.left : editingRegion.left + selectionEndpoints.first.point.dx,
      editingRegion.top + selectionEndpoints.first.point.dy - startGlyphHeight,
      isMultiline ? editingRegion.right : editingRegion.left + selectionEndpoints.last.point.dx,
      editingRegion.top + selectionEndpoints.last.point.dy,
    );
  }

  Offset _primaryAnchor({
    required Rect editingRegion,
    required Rect selectionRectangle,
    required Offset? secondaryTapPosition,
  }) {
    if (secondaryTapPosition != null) {
      return secondaryTapPosition;
    }
    if (selectionRectangle == Rect.zero) {
      return Offset.zero;
    }
    return Offset(
      selectionRectangle.left + selectionRectangle.width / 2,
      clampDouble(
        selectionRectangle.top,
        editingRegion.top,
        editingRegion.bottom,
      ),
    );
  }

  void _handleExternalDismissal() {
    if (!mounted) {
      return;
    }
    widget.editableTextState.hideToolbar(false);
    widget.onExternalDismissed();
  }

  void _handleActionDismissal() {
    if (!mounted) {
      return;
    }
    _shown = false;
    _presentationPending = false;
    _lastPresentedTableRevision = -1;
    _sessionIdentifier = _coordinator.createSessionIdentifier();
    setState(() {});
  }
}
