part of 'skeleton.dart';

final class _SkeletonCrossfadeTransition extends SkeletonTransition {
  const new({
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.linear,
  }) : super._();

  @override
  final Duration duration;

  @override
  final Curve curve;

  @override
  Widget Function(Widget, Widget, Animation<double>)? get _builder => null;
}
