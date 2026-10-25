part of 'contour.dart';

class _ContourViewMetricsObserver with WidgetsBindingObserver {
  new _();

  static final shared = _ContourViewMetricsObserver._();
  final _owners = <WeakReference<_RenderContour>>{};

  WeakReference<_RenderContour> register(_RenderContour owner) {
    if (_owners.isEmpty) WidgetsBinding.instance.addObserver(this);
    final registration = WeakReference(owner);
    _owners.add(registration);
    return registration;
  }

  void unregister(WeakReference<_RenderContour>? registration) {
    _owners.remove(registration);
    if (_owners.isEmpty) WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeMetrics() {
    // Live foreground already invalidates ordinary layer changes. Observe the
    // real View here so a fixed MediaQuery cannot retain an old-density atlas.
    for (final registration in _owners.toList(growable: false)) {
      final owner = registration.target;
      if (owner == null || !owner.attached) {
        _owners.remove(registration);
      } else {
        owner._viewMetricsChanged();
      }
    }
    if (_owners.isEmpty) WidgetsBinding.instance.removeObserver(this);
  }
}
