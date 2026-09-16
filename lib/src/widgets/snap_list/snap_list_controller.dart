part of 'snap_list.dart';

/// Observes a SnapList's position and moves to adjacent items.
///
/// Attach to one list at a time. Dispose the controller when no longer needed.
class SnapListController extends ChangeNotifier {
  _SnapListState? _client;

  /// Whether a list is attached to this controller.
  bool get hasClients => _client != null;

  /// The current real item, or null when detached or empty.
  ///
  /// Changes when an item settles. Trailing content keeps the last item index.
  int? get index => _client?._motion.index;

  /// Continuous item position; integer values are item anchors.
  ///
  /// A trailing reveal can exceed the last item's index.
  double? get position => _client?._motion.itemPosition;

  /// Whether the list is being dragged or animating, excluding a stationary trailing slot.
  bool get isMoving => _client?._motion.moving ?? false;

  /// Advances one item, completing true only when that item is reached.
  ///
  /// Completes false when unavailable, interrupted, detached, or settled on
  /// trailing content. Appending items there can advance the list afterward.
  Future<bool> next() => _client?._navigate(1) ?? Future<bool>.value(false);

  /// Returns one item, completing true only when that item is reached.
  Future<bool> previous() => _client?._navigate(-1) ?? Future<bool>.value(false);

  void _attach(_SnapListState client) {
    assert(_client == null || identical(_client, client), 'A SnapListController can only attach to one list.');
    _client = client;
  }

  void _detach(_SnapListState client) {
    if (identical(_client, client)) _client = null;
  }

  void _changed() => notifyListeners();

  @override
  void dispose() {
    _client?._detachController(this);
    _client = null;
    super.dispose();
  }
}
