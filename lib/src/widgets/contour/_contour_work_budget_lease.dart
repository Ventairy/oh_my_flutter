part of 'contour_work_budget.dart';

/// Holds a contour work reservation until its temporary resources are freed.
@internal
class ContourWorkBudgetLease {
  new _({required this._budget, required this.bytes, required this._background});

  /// The number of bytes reserved by this lease.
  final int bytes;

  ContourWorkBudget? _budget;
  final bool _background;

  /// Returns the reserved capacity and admits any newly eligible requests.
  ///
  /// Repeated calls have no effect. Release only after the work and resources
  /// covered by this reservation have finished, including cancelled work.
  void release() {
    final budget = _budget;
    if (budget == null) return;
    _budget = null;
    budget._release(bytes, background: _background);
  }
}
