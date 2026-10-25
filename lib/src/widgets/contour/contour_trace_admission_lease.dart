part of 'contour_trace_admission.dart';

/// Holds source capacity until its worker result has been consumed or discarded.
@internal
class ContourTraceAdmissionLease {
  new _({
    required this.usesSharedScratch,
    required ContourWorkBudgetLease lease,
    required this._onReleased,
  }) : bytes = lease.bytes,
       _lease = lease;

  /// Whether this source also owns a reference to the manager's shared workspace.
  final bool usesSharedScratch;

  /// The source allowance reserved independently of a shared workspace.
  final int bytes;

  ContourWorkBudgetLease? _lease;
  VoidCallback? _onReleased;
  VoidCallback? _acknowledgement;
  bool _acknowledgementBound = false;

  /// Acknowledges the worker once the owner has finished with its traced result.
  void bindAcknowledgement(VoidCallback callback) {
    assert(_lease != null, 'A released source cannot bind an acknowledgement.');
    assert(
      !_acknowledgementBound,
      'A source accepts only one acknowledgement.',
    );
    _acknowledgementBound = true;
    _acknowledgement = callback;
  }

  /// Acknowledges completion and releases capacity once, even if acknowledgement fails.
  void release() {
    final lease = _lease;
    if (lease == null) return;
    _lease = null;
    final acknowledgement = _acknowledgement;
    _acknowledgement = null;
    final onReleased = _onReleased;
    _onReleased = null;
    try {
      acknowledgement?.call();
    } finally {
      try {
        lease.release();
      } finally {
        onReleased?.call();
      }
    }
  }
}
