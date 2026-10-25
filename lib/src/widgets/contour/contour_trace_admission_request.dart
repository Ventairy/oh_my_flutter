part of 'contour_trace_admission.dart';

/// Allows a source awaiting contour capacity to be cancelled safely.
@internal
class ContourTraceAdmissionRequest {
  new _({
    required this._admission,
    required this._width,
    required this._height,
    required this._legacyBytes,
    required this._owner,
    required this._extraSourceBytes,
  });

  ContourTraceAdmission? _admission;
  final int _width;
  final int _height;
  final int _legacyBytes;
  final int _extraSourceBytes;
  Object? _owner;
  ContourWorkBudgetRequest? _workRequest;
  final Completer<ContourTraceAdmissionLease?> _completion = Completer();
  bool _cancelled = false;

  /// Completes with admitted capacity, or no lease after cancellation/rejection.
  Future<ContourTraceAdmissionLease?> get future => _completion.future;

  /// Cancels waiting work while preserving any lease already handed to its owner.
  void cancel() => _admission?._cancel(this);

  void _complete(ContourTraceAdmissionLease? lease) {
    _admission = null;
    _owner = null;
    _completion.complete(lease);
  }
}
