part of 'sequence.dart';

class _SequenceEntry {
  _SequenceEntry({
    required this.identity,
    required this.index,
    required this.child,
  }) : stackKey = ValueKey<Object>(identity);

  final Object identity;
  final Key stackKey;
  final GlobalKey subtreeKey = GlobalKey();
  int index;
  Widget child;
  AnimationController? animationController;
  SequenceTransitionBuilder? transition;
}
