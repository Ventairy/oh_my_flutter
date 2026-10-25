import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

part '_contour_work_budget_lease.dart';
part '_contour_work_budget_request.dart';

/// Limits concurrent contour work by reserving its estimated temporary bytes.
@internal
class ContourWorkBudget {
  /// Creates a budget allowing up to 64 MiB of concurrent work.
  new() : this._(maxBytes: 64 * 1024 * 1024);

  /// Creates an isolated budget with a deterministic capacity for tests.
  @visibleForTesting
  new test({required int maxBytes}) : this._(maxBytes: maxBytes);

  new _({required this.maxBytes}) : assert(maxBytes > 0, 'The work capacity must be positive.');

  /// The budget shared by contour renderers in the current isolate.
  static final ContourWorkBudget shared = ContourWorkBudget();

  /// The maximum number of bytes that active leases may reserve together.
  final int maxBytes;

  final Queue<ContourWorkBudgetRequest> _pendingForeground = Queue();
  final Queue<ContourWorkBudgetRequest> _pendingBackground = Queue();
  var _activeBytes = 0;
  var _peakBytes = 0;
  var _activeCount = 0;
  var _activeForegroundCount = 0;

  /// The number of bytes currently held by active leases.
  int get activeBytes => _activeBytes;

  /// The highest number of simultaneously reserved bytes since creation.
  int get peakBytes => _peakBytes;

  /// The number of requests waiting for capacity.
  int get pendingCount => _pendingForeground.length + _pendingBackground.length;

  /// The number of active leases that have not been released.
  int get activeCount => _activeCount;

  /// Reserves [bytes] when earlier requests and available capacity allow it.
  ///
  /// Foreground requests are admitted in arrival order. A [background] request
  /// waits until no foreground leases or queued foreground requests remain.
  /// Later foreground requests overtake waiting background work. Active
  /// background leases cannot be preempted and retain their reserved capacity.
  ///
  /// A request larger than [maxBytes] completes with `null` immediately. A queued
  /// request can be cancelled using its handle or [cancel]. Granted capacity
  /// remains reserved until the lease is released, including when the request's
  /// owner no longer needs the work.
  ContourWorkBudgetRequest request({required int bytes, required Object owner, bool background = false}) {
    assert(bytes > 0, 'A work reservation must contain a positive number of bytes.');
    final request = ContourWorkBudgetRequest._(budget: this, bytes: bytes, owner: owner, background: background);
    if (bytes > maxBytes) {
      request._complete(null);
      return request;
    }
    (background ? _pendingBackground : _pendingForeground).addLast(request);
    _drain();
    return request;
  }

  /// Cancels every queued request belonging to this exact [owner] object.
  ///
  /// Active leases remain reserved until their work releases them. Owners that
  /// compare equal are independent unless they are identical objects.
  void cancel(Object owner) {
    _cancelOwner(_pendingForeground, owner);
    _cancelOwner(_pendingBackground, owner);
    _drain();
  }

  void _cancelOwner(Queue<ContourWorkBudgetRequest> pending, Object owner) {
    final count = pending.length;
    for (var index = 0; index < count; index++) {
      final request = pending.removeFirst();
      if (identical(request._owner, owner)) {
        request._complete(null);
      } else {
        pending.addLast(request);
      }
    }
  }

  void _cancel(ContourWorkBudgetRequest request) {
    final pending = request._background ? _pendingBackground : _pendingForeground;
    if (!pending.remove(request)) return;
    request._complete(null);
    _drain();
  }

  void _drain() {
    while (_pendingForeground.isNotEmpty || _pendingBackground.isNotEmpty) {
      final foreground = _pendingForeground.isNotEmpty;
      if (!foreground && _activeForegroundCount > 0) return;
      final pending = foreground ? _pendingForeground : _pendingBackground;
      final request = pending.first;
      if (request._bytes > maxBytes - _activeBytes) return;
      pending.removeFirst();
      _activeBytes += request._bytes;
      _activeCount++;
      if (foreground) _activeForegroundCount++;
      if (_activeBytes > _peakBytes) _peakBytes = _activeBytes;
      request._complete(ContourWorkBudgetLease._(budget: this, bytes: request._bytes, background: request._background));
    }
  }

  void _release(int bytes, {required bool background}) {
    _activeBytes -= bytes;
    _activeCount--;
    if (!background) _activeForegroundCount--;
    _drain();
  }
}
