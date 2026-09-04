import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

/// Reports whether the benchmark target still owns an open native-menu session.
final class NativeSelectableTextBenchmarkMenuReadiness {
  const NativeSelectableTextBenchmarkMenuReadiness._({
    required this.nativeTargetCount,
    required this.editableTargetCount,
    required this.hasValidSelection,
    required this.selectionToolbarVisible,
    required this.adaptiveToolbarDetected,
  });

  /// Inspects the active widget tree below [root].
  factory NativeSelectableTextBenchmarkMenuReadiness.inspect(Element root) {
    var nativeTargetCount = 0;
    var editableTargetCount = 0;
    var hasValidSelection = false;
    var selectionToolbarVisible = false;
    var adaptiveToolbarDetected = false;

    void visit(Element element, {bool belowNativeTarget = false}) {
      final isNativeTarget = element.widget is NativeSelectableText;
      if (isNativeTarget) {
        nativeTargetCount += 1;
      }
      final isBelowNativeTarget = belowNativeTarget || isNativeTarget;
      if (isBelowNativeTarget && element is StatefulElement) {
        final state = element.state;
        if (state is EditableTextState) {
          editableTargetCount += 1;
          final value = state.textEditingValue;
          final selection = value.selection;
          final startIsInText = selection.start >= 0;
          final endIsInText = selection.end <= value.text.length;
          final selectionIsInText = startIsInText && endIsInText;
          final selectionHasRange = selection.isValid && !selection.isCollapsed;
          hasValidSelection = selectionHasRange && selectionIsInText;
          // Flutter exposes this diagnostic state specifically for inspection.
          // ignore: invalid_use_of_visible_for_testing_member
          final selectionOverlay = state.selectionOverlay;
          selectionToolbarVisible = selectionOverlay?.toolbarIsVisible ?? false;
        }
      }
      if (element.widget is AdaptiveTextSelectionToolbar) {
        adaptiveToolbarDetected = true;
      }
      element.visitChildElements(
        (child) => visit(
          child,
          belowNativeTarget: isBelowNativeTarget,
        ),
      );
    }

    visit(root);
    return NativeSelectableTextBenchmarkMenuReadiness._(
      nativeTargetCount: nativeTargetCount,
      editableTargetCount: editableTargetCount,
      hasValidSelection: hasValidSelection,
      selectionToolbarVisible: selectionToolbarVisible,
      adaptiveToolbarDetected: adaptiveToolbarDetected,
    );
  }

  /// The number of `NativeSelectableText` targets in the benchmark tree.
  final int nativeTargetCount;

  /// The number of editable states owned by those benchmark targets.
  final int editableTargetCount;

  /// Whether the target owns a valid, non-collapsed, in-bounds selection.
  final bool hasValidSelection;

  /// Whether Flutter still considers the target's context-menu overlay open.
  final bool selectionToolbarVisible;

  /// Whether Flutter's adaptive toolbar is mounted for the opened menu.
  final bool adaptiveToolbarDetected;

  /// Whether frame timing can proceed under a native-widget label.
  bool get isReady {
    return nativeTargetCount == 1 &&
        editableTargetCount == 1 &&
        hasValidSelection &&
        selectionToolbarVisible &&
        !adaptiveToolbarDetected;
  }

  /// A short description suitable for benchmark failure output.
  String get diagnostic {
    return 'native_targets=$nativeTargetCount, '
        'editable_targets=$editableTargetCount, '
        'valid_selection=$hasValidSelection, '
        'selection_toolbar_visible=$selectionToolbarVisible, '
        'adaptive_toolbar_detected=$adaptiveToolbarDetected';
  }

  /// Rejects a run that would measure Flutter's fallback as a native menu.
  void requireNativeMenu({String checkpoint = 'after opening the menu'}) {
    if (isReady) return;
    throw StateError(
      'NativeSelectableText menu readiness failed $checkpoint: $diagnostic. '
      'The benchmark target is missing, its selection or menu was dismissed, '
      'or the native host rejected presentation. This run would measure '
      "Flutter's adaptive fallback or no menu while "
      'reporting widget=native. '
      'Fix the native host or device state, then rerun the benchmark.',
    );
  }
}
