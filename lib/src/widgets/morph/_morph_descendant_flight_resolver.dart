part of 'morph.dart';

final class _MorphDescendantFlightResolver extends ChangeNotifier {
  _MorphDescendantFlightResolver({
    required _MorphDescendantCapture capture,
    required this._subtree,
  }) : _capture = capture {
    _refreshRecords();
    capture.addListener(_handleCaptureChanged);
  }

  final _MorphDescendantCapture _capture;
  final Widget _subtree;
  List<_MorphDescendantFlightRecord> _records = const [];
  final Map<_MorphDescendantState, _MorphDescendantFlightRecord> _resolvedRecords = Map.identity();
  int _recordsRevision = 0;

  int get recordsRevision => _recordsRevision;

  _MorphDescendantFlightRecord? resolve(_MorphDescendantState descendant) {
    _resolvedRecords.remove(descendant);
    final widget = descendant.widget;
    if (widget.flightBehavior.isLive) return null;
    final candidates = _records.where((record) => record.behavior == widget.flightBehavior);
    var matches = candidates.where((record) => identical(record.widget, widget));
    if (matches.isEmpty && widget.key != null) {
      matches = candidates.where((record) => record.key == widget.key);
    }
    if (matches.isEmpty) {
      matches = candidates.where((record) => record.childType == widget.child.runtimeType);
    }
    final record = matches.length == 1
        ? matches.single
        : matches.where((record) => !_resolvedRecords.containsValue(record)).firstOrNull;
    if (record != null) _resolvedRecords[descendant] = record;
    return record;
  }

  void release(_MorphDescendantState descendant) {
    _resolvedRecords.remove(descendant);
  }

  void _refreshRecords() {
    final records = _capture.records;
    final subtree = _subtree;
    _records = records.where((record) => record.belongsTo(subtree)).toList(growable: false);
    if (_records.isNotEmpty || subtree.key == null) return;
    _records = records
        .where(
          (record) => record.ancestors.any(
            (ancestor) => ancestor.key == subtree.key && ancestor.runtimeType == subtree.runtimeType,
          ),
        )
        .toList(growable: false);
  }

  void _handleCaptureChanged() {
    _refreshRecords();
    _resolvedRecords.clear();
    _recordsRevision += 1;
    notifyListeners();
  }

  @override
  void dispose() {
    _capture.removeListener(_handleCaptureChanged);
    super.dispose();
  }
}
