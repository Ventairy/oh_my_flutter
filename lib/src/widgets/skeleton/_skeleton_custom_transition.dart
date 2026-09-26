part of 'skeleton.dart';

final class _SkeletonCustomTransition extends SkeletonTransition {
  const new({
    required this.transitionBuilder,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.linear,
  }) : super._();

  final Widget Function(Widget, Widget, Animation<double>) transitionBuilder;

  @override
  final Duration duration;

  @override
  final Curve curve;

  @override
  Widget Function(Widget, Widget, Animation<double>) get _builder => transitionBuilder;
}
