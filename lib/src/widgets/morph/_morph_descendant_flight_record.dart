part of 'morph.dart';

final class _MorphDescendantFlightRecord {
  _MorphDescendantFlightRecord({
    required this.handle,
    required this.registrationOrder,
    required this.key,
    required this.childType,
    required this.behavior,
    required this.size,
    required this.snapshotRevision,
    required this.capturesContinuously,
    required this.snapshotCaptureCompleted,
    required this.snapshot,
  });

  final _MorphDescendantHandle handle;
  final int registrationOrder;
  final Key? key;
  final Type childType;
  final MorphDescendantFlightBehavior behavior;
  final Size size;
  final int snapshotRevision;
  final bool capturesContinuously;
  bool snapshotCaptureCompleted;
  _MorphContentSnapshot? snapshot;
  bool claimed = false;

  void retain() => snapshot?.retain();

  void release() => snapshot?.release();
}
