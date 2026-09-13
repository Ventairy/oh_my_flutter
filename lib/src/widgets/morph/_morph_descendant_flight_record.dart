part of 'morph.dart';

final class _MorphDescendantFlightRecord {
  _MorphDescendantFlightRecord({
    required this.handle,
    required this.widget,
    required this.ancestors,
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
  final MorphDescendant widget;
  final List<Widget> ancestors;
  final int registrationOrder;
  final Key? key;
  final Type childType;
  final MorphDescendantFlightBehavior behavior;
  final Size size;
  final int snapshotRevision;
  final bool capturesContinuously;
  bool snapshotCaptureCompleted;
  _MorphContentSnapshot? snapshot;

  bool belongsTo(Widget subtree) {
    for (final ancestor in ancestors) {
      if (identical(ancestor, subtree)) return true;
    }
    return false;
  }

  void retain() => snapshot?.retain();

  void release() => snapshot?.release();
}
