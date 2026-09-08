part of 'maybe_safe_area.dart';

/// Read the space occupied by safe-area-adjusted content from another renderer.
///
/// Attach this handle to one [MaybeSafeArea]. Read [adjustedBounds] while
/// painting, hit testing, or describing semantics, rather than during build or
/// layout. Listeners can safely request updates after the rendered frame.
/// Dispose the handle when its owning widget is removed.
///
/// See the [MaybeSafeArea guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/maybe_safe_area.md#observing-adjusted-bounds).
class MaybeSafeAreaHandle extends ChangeNotifier {
  _RenderMaybeSafeArea? _source;
  Rect? _bounds;
  Rect? _deliveredBounds;
  bool _delivered = false;
  bool _scheduled = false;
  bool _disposed = false;

  /// The corrected child bounds in the attached widget's local logical units.
  ///
  /// Returns null before attachment or usable layout. Reads resolve the current
  /// correction even before the attached widget paints. They do not notify
  /// listeners synchronously. A notification received after a frame can only
  /// affect a subsequent frame; this handle does not provide layout-time insets.
  Rect? get adjustedBounds {
    final source = _source;
    if (_disposed || source == null || !source.attached || !source.hasSize) return null;
    return MatrixUtils.transformRect(source._currentTransform, Offset.zero & source.size);
  }

  void _attach(_RenderMaybeSafeArea source) {
    assert(!_disposed, 'Cannot attach a disposed MaybeSafeAreaHandle.');
    assert(_source == null || identical(_source, source), 'A MaybeSafeAreaHandle supports only one attached source.');
    _source = source;
    _bounds = null;
    _delivered = false;
  }

  void _detach(_RenderMaybeSafeArea source) {
    if (!identical(_source, source)) return;
    _source = null;
    _publish(null);
  }

  void _publish(Rect? bounds) {
    if (_disposed) return;
    _bounds = bounds;
    if (!hasListeners || _scheduled || (_delivered && _deliveredBounds == bounds)) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed || !hasListeners || (_delivered && _deliveredBounds == _bounds)) return;
      _delivered = true;
      _deliveredBounds = _bounds;
      notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Starts observing resolved bounds, with notifications after a frame.
  ///
  /// The initial available result and subsequent changes are reported. Multiple
  /// changes within a frame are combined; unchanged bounds do not repeat.
  @override
  void addListener(VoidCallback listener) {
    final wasObserved = hasListeners;
    super.addListener(listener);
    if (wasObserved) return;
    _delivered = false;
    if (_bounds != null) _publish(_bounds);
  }

  /// Stops observations and releases the attached source reference.
  @override
  void dispose() {
    _disposed = true;
    _source = null;
    super.dispose();
  }
}
