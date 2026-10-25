part of 'contour.dart';

/// Coordinates preparation and entrances for a [Contour]'s content.
///
/// Listen for [isReady] before revealing content or starting its animation.
/// Attach this controller to one [Contour] at a time, and dispose it when it
/// is no longer needed. Use [Contour.prepareWhenHidden] when an ancestor hides
/// the child while preparation takes place.
///
/// See the [Contour guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/contour.md).
class ContourController extends ChangeNotifier {
  /// Creates a controller whose content is not ready until a [Contour] attaches.
  new();

  Object? _owner;
  bool _isReady = false;
  bool _lastNotifiedReady = false;
  bool _notificationScheduled = false;
  bool _disposed = false;
  int _notificationRevision = 0;

  /// Whether the current child and its available backing can be revealed.
  ///
  /// This becomes false when preparation is needed for changed content or when
  /// the [Contour] detaches. It also becomes true when decoration is transparent
  /// or preparation finishes without a backing for unsupported content.
  /// Readiness does not mean the content has reached the screen.
  ///
  /// Listeners are notified after the current synchronous work finishes. Several
  /// changes during that work are combined into the latest readiness value.
  bool get isReady => _isReady;

  /// Prepares the attached [Contour] again without revealing its content.
  ///
  /// Use this after changing artwork through a painter or another imperative
  /// source while an ancestor keeps the content hidden. Its next entrance can
  /// then wait for [isReady] again. The child must be mounted and laid out with
  /// the constraints it will use when shown.
  ///
  /// Calling this without an attached [Contour], or after disposal, does nothing.
  void prepare() {
    if (_disposed) return;
    if (_owner case final _RenderContour owner) owner._requestPreparation();
  }

  void _attach(Object owner, {required bool isReady}) {
    assert(!_disposed, 'A disposed ContourController cannot be attached.');
    assert(_owner == null || identical(_owner, owner), 'A ContourController can attach to only one Contour at a time.');
    if (_disposed || (_owner != null && !identical(_owner, owner))) return;
    if (!identical(_owner, owner)) _cancelNotification();
    _owner = owner;
    _setReady(isReady);
  }

  void _detach(Object owner) {
    if (_disposed || !identical(_owner, owner)) return;
    _owner = null;
    _cancelNotification();
    _setReady(false);
  }

  void _update(Object owner, {required bool isReady}) {
    if (_disposed || !identical(_owner, owner)) return;
    _setReady(isReady);
  }

  void _setReady(bool value) {
    _isReady = value;
    if (_notificationScheduled || _isReady == _lastNotifiedReady) return;
    _notificationScheduled = true;
    final revision = _notificationRevision;
    scheduleMicrotask(() {
      if (_disposed || revision != _notificationRevision) return;
      _notificationScheduled = false;
      if (_isReady == _lastNotifiedReady) return;
      _lastNotifiedReady = _isReady;
      notifyListeners();
    });
  }

  void _cancelNotification() {
    _notificationRevision++;
    _notificationScheduled = false;
  }

  /// Stops readiness notifications and releases this controller's listeners.
  @override
  void dispose() {
    _disposed = true;
    _owner = null;
    _isReady = false;
    _cancelNotification();
    super.dispose();
  }
}
