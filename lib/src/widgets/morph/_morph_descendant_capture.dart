part of 'morph.dart';

final class _MorphDescendantCapture extends ChangeNotifier {
  new() {
    _scheduleDisposal(afterFrame: false);
  }

  List<_MorphDescendantFlightRecord> _records = const [];
  bool acceptsRegistrations = true;
  bool hasRegistrations = false;
  final List<_MorphGroupCapture> _groups = [];
  bool groupsReady = true;
  bool get hasGroups => _groups.isNotEmpty;
  int get groupRevisionSignature {
    var signature = 0;
    for (final group in _groups) {
      signature = Object.hash(signature, group.currentRevision);
    }
    return signature;
  }

  bool get groupsAreCurrent {
    for (final group in _groups) {
      if (!group.isCurrent) return false;
    }
    return true;
  }

  int _references = 0;

  Widget registerGroup(GroupLink link, MorphEndpointContext endpoint) {
    assert(acceptsRegistrations, 'Register groups synchronously from properties.');
    hasRegistrations = true;
    final capture = _MorphSnapshotCapture.captureGroup(
      link,
      relativeTo: endpoint._renderObject,
      bounds: Offset.zero & endpoint.localSize,
      pixelRatio: View.of(endpoint.context).devicePixelRatio,
    );
    if (capture == null) {
      groupsReady = false;
      return const SizedBox.shrink();
    }
    final snapshot = capture.snapshot;
    final group = _MorphGroupCapture(
      link,
      snapshot,
      endpoint._renderObject,
      capture.revision,
    );
    _groups.add(group);
    return SizedBox.fromSize(
      size: snapshot.size,
      child: CustomPaint(painter: _MorphGroupSnapshotPainter(group)),
    );
  }

  VoidCallback beginGroupPresentation(_MorphVisibilityHandle? visibility) {
    final releases = [for (final group in _groups) group.beginPresentation(visibility)];
    return () {
      for (final release in releases) {
        release();
      }
    };
  }

  int _disposalGeneration = 0;
  bool _disposed = false;

  List<_MorphDescendantFlightRecord> get records => _records;

  Widget register(Widget child) {
    assert(
      acceptsRegistrations,
      'Call descendantWidget while MorphFlightDelegate.properties is running. '
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
      for (final group in _groups) {
        group.dispose();
      }
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
