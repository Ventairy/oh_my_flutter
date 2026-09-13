part of 'morph.dart';

final class _MorphAutoFlightConfiguration extends MorphFlightConfig {
  const _MorphAutoFlightConfiguration({
    this.childSwitchAt = 0.5,
    this.childTransition,
  }) : assert(
         childSwitchAt >= 0 && childSwitchAt <= 1,
         'childSwitchAt must be between 0 and 1.',
       ),
       super._();

  final double childSwitchAt;
  final Widget Function(Widget child, Animation<double> animation)? childTransition;
}
