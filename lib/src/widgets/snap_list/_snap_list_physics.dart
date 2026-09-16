part of 'snap_list.dart';

class _SnapListPhysics extends ScrollPhysics {
  const _SnapListPhysics({super.parent});

  @override
  _SnapListPhysics applyTo(ScrollPhysics? ancestor) => _SnapListPhysics(parent: buildParent(ancestor));

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) =>
      value - value.clamp(position.minScrollExtent, position.maxScrollExtent);

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) => null;

  @override
  bool get allowImplicitScrolling => false;
}
