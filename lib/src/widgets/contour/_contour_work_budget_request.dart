part of 'contour_work_budget.dart';

/// Allows a queued contour reservation to be awaited or cancelled.
@internal
class ContourWorkBudgetRequest {
  new _({required this._budget, required this._bytes, required this._owner, required this._background});

  ContourWorkBudget? _budget;
  final int _bytes;
  final bool _background;
  Object? _owner;
  final Completer<ContourWorkBudgetLease?> _completion = Completer();

  /// Completes with a lease when admitted, or `null` when cancelled or too large.
  Future<ContourWorkBudgetLease?> get future => _completion.future;

  /// Cancels the reservation if it is still waiting for capacity.
  ///
  /// Cancelling an admitted request does not release its lease. The work must
  /// release that lease after it has finished with the reserved resources.
  void cancel() => _budget?._cancel(this);

  void _complete(ContourWorkBudgetLease? lease) {
    _budget = null;
    _owner = null;
    _completion.complete(lease);
  }
}
