part of 'morph.dart';

final class _MorphDescendantFlightRecord {
  _MorphDescendantFlightRecord({
    required this.registrationOrder,
    required this.key,
    required this.childType,
    required this.behavior,
    required this.size,
    required this.snapshot,
  });

  final int registrationOrder;
  final Key? key;
  final Type childType;
  final MorphDescendantFlightBehavior behavior;
  final Size size;
  _MorphContentSnapshot? snapshot;
  bool claimed = false;

  void retain() => snapshot?.retain();

  void release() => snapshot?.release();
}
