part of 'morph.dart';

final class _MorphTextRasterPool {
  _MorphTextRasterPool() {
    _scheduler = _MorphRasterSnapshotScheduler<_MorphTextRasterPoolKey, _MorphTextRasterPoolReservation>(
      _disposeScheduledReservation,
      maximumPending: _maximumPending,
    );
    _MorphTextRasterPoolRegistry.register(this);
    _finalizer.attach(this, _finalizerToken, detach: this);
  }

  // Four matched Text children can each use a source and destination content
  // segment in both directions. Keep that bounded steady-state working set so
  // alternating flights do not sequentially evict the entries needed next.
  static const int _maximumEntries = 16;
  static const int _maximumPixels = 4 * 1024 * 1024;
  static const int _maximumPending = 4;
  static final Finalizer<_MorphTextRasterPoolFinalizerToken> _finalizer = Finalizer<_MorphTextRasterPoolFinalizerToken>(
    (token) {
      try {
        token.dispose();
      } finally {
        _MorphTextRasterPoolRegistry.prune();
      }
    },
  );

  final Map<_MorphTextRasterPoolKey, _MorphTextRasterPoolEntry> _entries =
      <_MorphTextRasterPoolKey, _MorphTextRasterPoolEntry>{};
  final Set<_MorphTextRasterPoolEntry> _ownedEntries = Set<_MorphTextRasterPoolEntry>.identity();
  final Set<_MorphTextRasterPoolReservation> _reservations = Set<_MorphTextRasterPoolReservation>.identity();
  late final _MorphRasterSnapshotScheduler<_MorphTextRasterPoolKey, _MorphTextRasterPoolReservation> _scheduler;
  int _pixels = 0;
  int _ownedPixels = 0;
  int _reservedPixels = 0;
  int _generation = 0;
  bool _disposed = false;
  bool _finalizerAttached = true;
  int _hits = 0;
  int _misses = 0;
  int _creates = 0;
  final _MorphTextRasterPoolFinalizerToken _finalizerToken = _MorphTextRasterPoolFinalizerToken();

  int get debugEntryCount => _entries.length;

  int get debugRegisteredPoolCount {
    return _MorphTextRasterPoolRegistry.debugPoolCount;
  }

  int get debugPixelCount => _pixels;

  int get debugOwnedEntryCount => _ownedEntries.length;

  int get debugOwnedPixelCount => _ownedPixels;

  int get debugReservedEntryCount => _reservations.length;

  int get debugReservedPixelCount => _reservedPixels;

  int get debugBudgetedEntryCount {
    return _ownedEntries.length + _reservations.length;
  }

  int get debugBudgetedPixelCount => _ownedPixels + _reservedPixels;

  bool get debugFinalizerAttached => _finalizerAttached;

  int get debugPendingCount => _scheduler.debugRunningCount;

  int get debugDeferredCount => _scheduler.debugDeferredCount;

  bool get debugHasScheduledFrame => _scheduler.debugHasScheduledFrame;

  int get debugStartCount => _scheduler.debugStartCount;

  int get debugLateDisposalCount => _scheduler.debugLateDisposalCount;

  int get debugHitCount => _hits;

  int get debugMissCount => _misses;

  int get debugCreateCount => _creates;

  _MorphTextRasterPoolLease? acquire(_MorphTextRasterPoolKey key) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    _entries[key] = entry;
    _hits += 1;
    return _lease(entry);
  }

  ({
    Future<_MorphTextRasterPoolLease>? lease,
    Future<bool>? retry,
    VoidCallback? cancelRetry,
  })?
  load(
    _MorphTextRasterPoolKey key,
    Future<ui.Image> Function() loader,
  ) {
    if (_disposed) return null;
    final entry = _entries.remove(key);
    if (entry != null) {
      _entries[key] = entry;
      _hits += 1;
      return (
        lease: Future<_MorphTextRasterPoolLease>.value(_lease(entry)),
        retry: null,
        cancelRetry: null,
      );
    }
    Future<_MorphTextRasterPoolReservation> guardedLoader() async {
      final reservation = _reserve(key);
      if (reservation == null) {
        throw StateError(
          'The Morph text raster pool has no remaining image budget.',
        );
      }
      try {
        reservation.image = await loader();
        return reservation;
      } on Object {
        _releaseReservation(reservation);
        rethrow;
      }
    }

    final admission = _scheduler.load(key, guardedLoader);
    if (admission == null) return null;
    final retry = admission.retry;
    if (retry != null) {
      return (
        lease: null,
        retry: retry,
        cancelRetry: admission.cancelRetry,
      );
    }
    final pending = admission.value!;
    if (!admission.isNew) {
      _hits += 1;
    } else {
      final generation = _generation;
      _misses += 1;
      unawaited(
        pending.then(
          (reservation) {
            if (_disposed || generation != _generation) {
              reservation.disposeImage();
              _releaseReservation(reservation);
              return;
            }
            _creates += 1;
            _insert(key, reservation);
          },
          onError: (Object _, StackTrace _) {},
        ),
      );
    }
    return (
      lease: pending.then((_) {
        final completed = _entries[key];
        if (completed == null) {
          throw StateError(
            'The Morph text raster was invalidated before acquisition.',
          );
        }
        return _lease(completed);
      }),
      retry: null,
      cancelRetry: null,
    );
  }

  void release(_MorphTextRasterPoolEntry entry) {
    assert(entry.leases > 0, 'A Morph text raster lease was released twice.');
    entry.leases -= 1;
    if (entry.leases == 0 && entry.evicted) _disposeEntry(entry);
  }

  void clear() {
    if (_disposed) return;
    _generation += 1;
    _scheduler.clear();
    _clearEntries();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _MorphTextRasterPoolRegistry.unregister(this);
    _generation += 1;
    _scheduler.dispose();
    _clearEntries();
    _detachFinalizerIfIdle();
  }

  void _clearEntries() {
    _entries.values.forEach(_evictEntry);
    _entries.clear();
    _pixels = 0;
  }

  _MorphTextRasterPoolReservation? _reserve(
    _MorphTextRasterPoolKey key,
  ) {
    if (key.pixels > _maximumPixels) return null;

    while (_wouldExceedBudget(key)) {
      _MorphTextRasterPoolKey? evictionKey;
      _MorphTextRasterPoolEntry? eviction;
      for (final candidate in _entries.entries) {
        if (candidate.value.leases != 0) continue;
        evictionKey = candidate.key;
        eviction = candidate.value;
        break;
      }
      if (evictionKey == null || eviction == null) return null;
      _entries.remove(evictionKey);
      _pixels -= eviction.key.pixels;
      _evictEntry(eviction);
    }

    final reservation = _MorphTextRasterPoolReservation(key);
    _reservations.add(reservation);
    _reservedPixels += key.pixels;
    return reservation;
  }

  bool _wouldExceedBudget(_MorphTextRasterPoolKey key) {
    return _ownedEntries.length + _reservations.length + 1 > _maximumEntries ||
        _ownedPixels + _reservedPixels + key.pixels > _maximumPixels;
  }

  void _releaseReservation(
    _MorphTextRasterPoolReservation reservation,
  ) {
    if (!_reservations.remove(reservation)) return;
    _reservedPixels -= reservation.key.pixels;
  }

  void _insert(
    _MorphTextRasterPoolKey key,
    _MorphTextRasterPoolReservation reservation,
  ) {
    assert(
      _reservations.contains(reservation),
      'A completed Morph raster must retain its image reservation.',
    );
    final replaced = _entries.remove(key);
    if (replaced != null) {
      _pixels -= replaced.key.pixels;
      _evictEntry(replaced);
    }
    final image = reservation.takeImage();
    _releaseReservation(reservation);
    final entry = _MorphTextRasterPoolEntry(key: key, image: image);
    _entries[key] = entry;
    _ownedEntries.add(entry);
    _finalizerToken.images.add(image);
    _pixels += key.pixels;
    _ownedPixels += key.pixels;
    assert(
      _ownedEntries.length + _reservations.length <= _maximumEntries &&
          _ownedPixels + _reservedPixels <= _maximumPixels,
      'The Morph raster pool exceeded its owned image budget.',
    );
  }

  _MorphTextRasterPoolLease _lease(_MorphTextRasterPoolEntry entry) {
    entry.leases += 1;
    return _MorphTextRasterPoolLease(this, entry);
  }

  void _evictEntry(_MorphTextRasterPoolEntry entry) {
    entry.evicted = true;
    if (entry.leases == 0) _disposeEntry(entry);
  }

  void _disposeEntry(_MorphTextRasterPoolEntry entry) {
    if (!_ownedEntries.contains(entry)) return;
    _finalizerToken.images.remove(entry.image);
    entry.dispose();
    _ownedEntries.remove(entry);
    _ownedPixels -= entry.key.pixels;
    _detachFinalizerIfIdle();
  }

  void _disposeScheduledReservation(
    _MorphTextRasterPoolReservation reservation,
  ) {
    reservation.disposeImage();
    _releaseReservation(reservation);
  }

  void _detachFinalizerIfIdle() {
    if (!_disposed || !_finalizerAttached || _ownedEntries.isNotEmpty) {
      return;
    }
    _finalizerAttached = false;
    _finalizer.detach(this);
  }
}
