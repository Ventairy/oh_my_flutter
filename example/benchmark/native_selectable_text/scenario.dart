/// Workload exercised by one NativeSelectableText benchmark process.
enum NativeSelectableTextBenchmarkScenario {
  /// Continuously scrolls a lazy list of selectable text widgets.
  scroll,

  /// Opens the selection menu and changes the selected range every frame.
  selection,

  /// Opens the selection menu while leaving selection and geometry unchanged.
  menuIdle;

  /// Whether [value] is a supported stable CLI identifier.
  static bool accepts(String value) {
    return value == 'scroll' || value == 'selection' || value == 'menu_idle';
  }

  /// Parses the stable CLI and log identifier in [value].
  static NativeSelectableTextBenchmarkScenario parse(String value) {
    return switch (value) {
      'scroll' => scroll,
      'selection' => selection,
      'menu_idle' => menuIdle,
      _ => throw ArgumentError.value(
        value,
        'scenario',
        'must be scroll, selection, or menu_idle',
      ),
    };
  }

  /// Stable identifier used by dart-defines and machine-readable records.
  String get id {
    return switch (this) {
      scroll => 'scroll',
      selection => 'selection',
      menuIdle => 'menu_idle',
    };
  }

  /// Whether this workload opens a selection menu before measurement.
  bool get opensMenu {
    return switch (this) {
      scroll => false,
      selection || menuIdle => true,
    };
  }

  /// Whether every ticker callback moves the selected range.
  bool get updatesSelection {
    return switch (this) {
      scroll || menuIdle => false,
      selection => true,
    };
  }

  /// Whether every ticker callback moves the scroll position.
  bool get updatesScrollPosition {
    return switch (this) {
      scroll => true,
      selection || menuIdle => false,
    };
  }
}
