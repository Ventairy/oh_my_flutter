part of 'maybe_safe_area.dart';

/// Reads unsafe edge overlap and observes changes for one [SafeAreaObserver].
///
/// Own this handle in State and dispose it with that State. Read live insets
/// during painting or interaction, or cache notified values for later layout.
/// Notifications arrive after a frame and cannot reflow that completed frame.
class SafeAreaObserverHandle extends ChangeNotifier {
  _RenderSafeAreaObserver? _source;
  EdgeInsets? _insets;
  EdgeInsets? _deliveredInsets;
  bool _delivered = false;
  bool _scheduled = false;
  bool _disposed = false;

  /// The unsafe edge overlap in the attached widget's local logical units.
  ///
  /// Returns null before attachment or usable layout, and zero when the region
  /// does not overlap any enabled unsafe edge. Reads resolve the current
  /// measurement even before the attached widget paints. They do not notify
  /// listeners synchronously. A notification received after a frame can only
  /// affect a subsequent frame; this handle does not provide layout-time insets.
  EdgeInsets? get avoidanceInsets {
    final source = _source;
    if (_disposed || source == null || !source.attached || !source.hasSize) return null;
    return source.currentInsets;
  }

  void _attach(_RenderSafeAreaObserver source) {
    assert(!_disposed, 'Cannot attach a disposed SafeAreaObserverHandle.');
    assert(
      _source == null || identical(_source, source),
      'A SafeAreaObserverHandle supports only one attached source.',
    );
    _source = source;
    _insets = null;
    _delivered = false;
  }

  void _detach(_RenderSafeAreaObserver source) {
    if (!identical(_source, source)) return;
    _source = null;
    _publish(null);
  }

  void _publish(EdgeInsets? insets) {
    if (_disposed) return;
    _insets = insets;
    if (!hasListeners || _scheduled || (_delivered && _deliveredInsets == insets)) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed || !hasListeners || (_delivered && _deliveredInsets == _insets)) return;
      _delivered = true;
      _deliveredInsets = _insets;
      notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Starts observing resolved insets, with notifications after a frame.
  ///
  /// The initial available result and subsequent changes are reported. Multiple
  /// changes within a frame are combined; unchanged insets do not repeat.
  @override
  void addListener(VoidCallback listener) {
    final wasObserved = hasListeners;
    super.addListener(listener);
    if (wasObserved) return;
    _delivered = false;
    if (_insets != null) _publish(_insets);
  }

  /// Stops observations and releases the attached source reference.
  @override
  void dispose() {
    _disposed = true;
    _source = null;
    super.dispose();
  }
}
