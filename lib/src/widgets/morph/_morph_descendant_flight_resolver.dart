part of 'morph.dart';

final class _MorphDescendantFlightResolver extends ChangeNotifier {
  _MorphDescendantFlightResolver({
    required this.animation,
    required this.switchThreshold,
    required this.source,
    required this.destination,
  }) : _showsSource = animation.value < switchThreshold {
    animation.addListener(_handleAnimationChanged);
  }

  final Animation<double> animation;
  final double switchThreshold;
  final List<_MorphDescendantFlightRecord> source;
  final List<_MorphDescendantFlightRecord> destination;
  bool _showsSource;
  int _recordsRevision = 0;

  bool get showsSource => _showsSource;

  int get recordsRevision => _recordsRevision;

  void recordsChanged() {
    _recordsRevision += 1;
    notifyListeners();
  }

  _MorphDescendantFlightRecord? claim({
    required Key? key,
    required Type childType,
    required MorphDescendantFlightBehavior behavior,
  }) {
    final records = showsSource ? source : destination;
    if (key != null) {
      for (final record in records) {
        if (!record.claimed && record.key == key && record.behavior == behavior) {
          record.claimed = true;
          return record;
        }
      }
    }
    for (final record in records) {
      if (!record.claimed && record.childType == childType && record.behavior == behavior) {
        record.claimed = true;
        return record;
      }
    }
    return null;
  }

  void release(_MorphDescendantFlightRecord? record) {
    if (record == null) return;
    record.claimed = false;
  }

  void _handleAnimationChanged() {
    final showsSource = animation.value < switchThreshold;
    if (showsSource == _showsSource) return;
    _showsSource = showsSource;
    notifyListeners();
  }

  @override
  void dispose() {
    animation.removeListener(_handleAnimationChanged);
    super.dispose();
  }
}
