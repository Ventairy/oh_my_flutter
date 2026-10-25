import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'contour_work_budget.dart';

part 'contour_trace_admission_lease.dart';
part 'contour_trace_admission_request.dart';

/// Reserves source captures while sharing one bounded tracing workspace.
@internal
class ContourTraceAdmission {
  /// Creates admission accounting within the supplied existing work budget.
  new({
    required this._budget,
    required int maximumPixels,
    required int maxGeometryBytes,
    required int maxContourPoints,
  }) : assert(maximumPixels > 0, 'The source pixel limit must be positive.'),
       assert(maxGeometryBytes > 0, 'The geometry limit must be positive.'),
       assert(
         maxContourPoints > 0,
         'The contour point limit must be positive.',
       ),
       // With both capture axes at most 4096, rounding their product upward
       // adds fewer than 4096 + 4096 - 1 = 8191 pixels to its unrounded area.
       _maximumCapturePixels = maximumPixels + 8191,
       // A padded byte plane adds 2 * width + 2 * height + 4 bytes,
       // at most 16388 beyond the ceil-adjusted source pixel allowance.
       scratchBytes = 3 * (maximumPixels + 8191 + 16388) + 3 * maxGeometryBytes + 128 * maxContourPoints + 64 * 1024;

  static const _maximumAxis = 4096;
  static const int _sourceOverheadBytes = 64 * 1024;

  final ContourWorkBudget _budget;
  final int _maximumCapturePixels;
  final Queue<ContourTraceAdmissionRequest> _pending = Queue();
  final Queue<ContourTraceAdmissionRequest> _waitingForScratch = Queue();
  ContourWorkBudgetRequest? _scratchRequest;
  ContourWorkBudgetLease? _scratchLease;
  bool _scratchCancelled = false;
  bool _draining = false;
  int _sharedCount = 0;
  int _legacyCount = 0;
  int _shutdownHolds = 0;
  int _peakScratchBytes = 0;
  int _activeSourceBytes = 0;
  int _peakSourceBytes = 0;
  int _peakSharedCount = 0;

  /// The shared workspace reservation, including padded planes and fitting work.
  final int scratchBytes;

  /// The workspace capacity currently held, excluding a pending floor request.
  int get activeScratchBytes => _scratchLease?.bytes ?? 0;

  /// The largest workspace allowance granted during this manager's lifetime.
  int get peakScratchBytes => _peakScratchBytes;

  /// The source allowances delivered to owners and not yet released.
  int get activeSourceBytes => _activeSourceBytes;

  /// The largest sum of delivered source allowances held concurrently.
  ///
  /// Technical fallback sources count their full legacy leases.
  int get peakSourceBytes => _peakSourceBytes;

  /// The largest shared cohort, including sources waiting for payload capacity.
  int get peakSharedCount => _peakSharedCount;

  /// The shared sources holding capacity or waiting for their source capacity.
  int get sharedCount => _sharedCount;

  /// The sources waiting here before a request reaches the underlying budget.
  int get deferredCount => _pending.length + _waitingForScratch.length;

  /// The legacy sources holding capacity or waiting in the underlying budget.
  int get legacyCount => _legacyCount;

  /// Reserves a source before capture, or its full legacy allowance when needed.
  ///
  /// Unsupported capture dimensions use the exclusive legacy path. A request
  /// larger than the entire budget completes with no lease immediately.
  /// [extraSourceBytes] reserves additional storage alongside a shared
  /// source. Include that storage in the complete [legacyBytes] total as well.
  ContourTraceAdmissionRequest request({
    required int width,
    required int height,
    required int legacyBytes,
    required Object owner,
    int extraSourceBytes = 0,
  }) {
    assert(width > 0 && height > 0, 'Capture dimensions must be positive.');
    assert(legacyBytes > 0, 'The legacy reservation must be positive.');
    assert(extraSourceBytes >= 0, 'Additional source storage cannot be negative.');
    final request = ContourTraceAdmissionRequest._(
      admission: this,
      width: width,
      height: height,
      legacyBytes: legacyBytes,
      owner: owner,
      extraSourceBytes: extraSourceBytes,
    );
    if (legacyBytes > _budget.maxBytes) {
      request._complete(null);
    } else {
      _pending.addLast(request);
      _drain();
    }
    return request;
  }

  /// Keeps an existing workspace reserved until worker shutdown really finishes.
  ///
  /// This hold survives source acknowledgements and cancellation. It is not
  /// needed before a workspace has been granted, because no pooled work can
  /// have started at that point.
  void retainScratchUntil(Future<void> completion) {
    if (_scratchLease == null) return;
    _shutdownHolds++;
    void releaseHold() {
      _shutdownHolds--;
      _releaseUnusedScratch();
      _drain();
    }

    unawaited(
      completion.then<void>(
        (_) => releaseHold(),
        onError: (Object _, StackTrace _) => releaseHold(),
      ),
    );
  }

  bool _supportsShared(ContourTraceAdmissionRequest request) {
    if (request._width > _maximumAxis || request._height > _maximumAxis) return false;
    final pixels = request._width * request._height;
    return pixels <= _maximumCapturePixels &&
        scratchBytes + pixels * 12 + _sourceOverheadBytes + request._extraSourceBytes <= _budget.maxBytes;
  }

  bool get _idle => _sharedCount == 0 && _scratchRequest == null && _scratchLease == null;

  void _drain() {
    if (_draining || _legacyCount > 0) return;
    _draining = true;
    try {
      while (_pending.isNotEmpty && _legacyCount == 0) {
        final request = _pending.first;
        final legacy = !_supportsShared(request) || (_idle && (_budget.activeCount > 0 || _budget.pendingCount > 0));
        if (legacy) {
          // Never queue a full legacy reservation behind our own floor. It may
          // need every byte the floor holds, including during worker shutdown.
          if (_sharedCount > 0 || _shutdownHolds > 0) return;
          _releaseUnusedScratch();
          if (_scratchRequest != null || _scratchLease != null) return;
          _pending.removeFirst();
          _submitLegacy(request);
          return;
        }
        _pending.removeFirst();
        _sharedCount++;
        if (_sharedCount > _peakSharedCount) _peakSharedCount = _sharedCount;
        if (_scratchLease == null) {
          _waitingForScratch.addLast(request);
          _ensureScratch();
        } else {
          _submitSource(request);
        }
      }
      _releaseUnusedScratch();
    } finally {
      _draining = false;
    }
  }

  void _ensureScratch() {
    if (_scratchRequest != null || _scratchLease != null || _sharedCount == 0) return;
    final request = _budget.request(bytes: scratchBytes, owner: this);
    _scratchRequest = request;
    _scratchCancelled = false;
    unawaited(
      request.future.then((lease) {
        assert(
          identical(_scratchRequest, request),
          'A scratch request must settle before its replacement.',
        );
        _scratchRequest = null;
        if (lease != null && lease.bytes > _peakScratchBytes) _peakScratchBytes = lease.bytes;
        final cancelled = _scratchCancelled;
        _scratchCancelled = false;
        if (cancelled || _sharedCount == 0 || lease == null) {
          lease?.release();
          if (!cancelled && lease == null && _sharedCount > 0) {
            while (_waitingForScratch.isNotEmpty) {
              final waiting = _waitingForScratch.removeFirst();
              _sharedCount--;
              waiting._complete(null);
            }
          }
          _ensureScratch();
        } else {
          _scratchLease = lease;
          while (_waitingForScratch.isNotEmpty) {
            _submitSource(_waitingForScratch.removeFirst());
          }
        }
        _drain();
      }),
    );
  }

  void _submitSource(ContourTraceAdmissionRequest request) {
    _submit(
      request,
      bytes: request._width * request._height * 12 + _sourceOverheadBytes + request._extraSourceBytes,
      shared: true,
    );
  }

  void _submitLegacy(ContourTraceAdmissionRequest request) {
    _legacyCount++;
    _submit(request, bytes: request._legacyBytes, shared: false);
  }

  void _submit(
    ContourTraceAdmissionRequest request, {
    required int bytes,
    required bool shared,
  }) {
    final pending = _budget.request(bytes: bytes, owner: request._owner!);
    request._workRequest = pending;
    unawaited(
      pending.future.then((lease) {
        request._workRequest = null;
        if (request._cancelled || lease == null) {
          lease?.release();
          _finish(request, shared: shared);
          request._complete(null);
          return;
        }
        _activeSourceBytes += lease.bytes;
        if (_activeSourceBytes > _peakSourceBytes) _peakSourceBytes = _activeSourceBytes;
        request._complete(
          ContourTraceAdmissionLease._(
            usesSharedScratch: shared,
            lease: lease,
            onReleased: () {
              _activeSourceBytes -= lease.bytes;
              _finish(request, shared: shared);
            },
          ),
        );
      }),
    );
  }

  void _finish(ContourTraceAdmissionRequest request, {required bool shared}) {
    if (shared) {
      _sharedCount--;
      _releaseUnusedScratch();
    } else {
      _legacyCount--;
    }
    _drain();
  }

  void _releaseUnusedScratch() {
    if (_sharedCount != 0 || _shutdownHolds != 0) return;
    if (_scratchRequest case final request?) {
      _scratchCancelled = true;
      request.cancel();
      // Even a cancelled request may already own an asynchronously delivered
      // grant. Its completion releases that grant before the legacy gate opens.
      return;
    }
    final lease = _scratchLease;
    _scratchLease = null;
    lease?.release();
  }

  void _cancel(ContourTraceAdmissionRequest request) {
    if (_pending.remove(request)) {
      request
        .._cancelled = true
        .._complete(null);
      _drain();
      return;
    }
    if (_waitingForScratch.remove(request)) {
      request._cancelled = true;
      _sharedCount--;
      request._complete(null);
      _releaseUnusedScratch();
      _drain();
      return;
    }
    if (request._workRequest case final pending?) {
      request._cancelled = true;
      pending.cancel();
    }
  }
}
