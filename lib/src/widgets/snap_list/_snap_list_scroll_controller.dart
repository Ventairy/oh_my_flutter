part of 'snap_list.dart';

class _SnapListScrollController extends ScrollController {
  _SnapListScrollController(this.motion);
  final _SnapListMotion motion;

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) =>
      _SnapListPosition(physics: physics, context: context, motion: motion, oldPosition: oldPosition);
}
