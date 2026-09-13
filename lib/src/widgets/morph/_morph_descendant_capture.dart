part of 'morph.dart';

final class _MorphDescendantCapture extends ChangeNotifier {
  _MorphDescendantCapture() {
    _scheduleDisposal(afterFrame: false);
  }

  List<_MorphDescendantFlightRecord> _records = const [];
  bool acceptsRegistrations = true;
  bool hasRegistrations = false;
  int _references = 0;
  int _disposalGeneration = 0;
  bool _disposed = false;

  List<_MorphDescendantFlightRecord> get records => _records;

  Widget register(Widget child) {
    assert(
      acceptsRegistrations,
      'Call registerDescendantWidget while MorphFlightDelegate.properties is running. '
      'Keep the returned widget instead of retaining the endpoint context.',
    );
    hasRegistrations = true;
    return _MorphRegisteredDescendant(capture: this, child: child);
  }

  void replaceRecords(List<_MorphDescendantFlightRecord> records) {
    if (_references > 0) {
      for (final record in records) {
        record.retain();
      }
      for (final record in _records) {
        record.release();
      }
    }
    _records = records;
    notifyListeners();
  }

  void retain() {
    assert(!_disposed, 'A completed Morph capture cannot be used in another flight.');
    _disposalGeneration += 1;
    _references += 1;
    if (_references != 1) return;
    for (final record in _records) {
      record.retain();
    }
  }

  void release() {
    assert(_references > 0, 'A Morph capture must be retained before it is released.');
    _references -= 1;
    if (_references != 0) return;
    for (final record in _records) {
      record.release();
    }
    _scheduleDisposal(afterFrame: true);
  }

  void _scheduleDisposal({required bool afterFrame}) {
    final generation = ++_disposalGeneration;
    void disposeIfUnused() {
      if (_disposed || _references != 0 || generation != _disposalGeneration) {
        return;
      }
      _disposed = true;
      dispose();
    }

    if (afterFrame) {
      SchedulerBinding.instance.addPostFrameCallback((_) => disposeIfUnused());
      SchedulerBinding.instance.ensureVisualUpdate();
    } else {
      scheduleMicrotask(disposeIfUnused);
    }
  }
}
