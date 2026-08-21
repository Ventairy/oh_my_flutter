part of 'morph.dart';

final class _MorphSnapshotAtlas {
  _MorphSnapshotAtlas(this.image) {
    _scheduleDisposalIfUnused(afterFrame: false);
  }

  final ui.Image image;
  int _references = 0;
  int _disposalGeneration = 0;
  bool _disposed = false;

  void retain() {
    assert(!_disposed, 'A disposed Morph snapshot cannot be retained.');
    _references += 1;
    _disposalGeneration += 1;
  }

  void release() {
    assert(
      _references > 0,
      'A Morph snapshot cannot be released without a matching retain.',
    );
    _references -= 1;
    _scheduleDisposalIfUnused(afterFrame: true);
  }

  void _scheduleDisposalIfUnused({required bool afterFrame}) {
    final generation = ++_disposalGeneration;
    void disposeIfUnused() {
      if (_disposed || _references != 0 || generation != _disposalGeneration) {
        return;
      }
      _disposed = true;
      image.dispose();
    }

    if (!afterFrame) {
      scheduleMicrotask(disposeIfUnused);
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) => disposeIfUnused());
    SchedulerBinding.instance.ensureVisualUpdate();
  }
}
