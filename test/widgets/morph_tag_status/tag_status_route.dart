import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

class TagStatusRoute extends PopupRoute<void> {
  final target = MorphTarget(tag: 'surface');
  late final ValueListenable<MorphTagStatus> status;
  Offset translation = Offset.zero;
  bool concealed = false;

  @override
  void install() {
    super.install();
    status = MorphNavigatorObserver.maybeOfNavigator(navigator!)!.tagStatus(target.tag);
    status.addListener(changedInternalState);
  }

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => Align(
    alignment: Alignment.bottomCenter,
    child: Morph(
      target: target,
      duration: const Duration(milliseconds: 300),
      child: const SizedBox(
        key: ValueKey('destination'),
        width: 200,
        height: 200,
        child: ColoredBox(
          color: Color(0xFF1565C0),
          child: Center(
            child: MorphDescendant(
              flightBehavior: MorphDescendantFlightBehavior.snapshot,
              child: SizedBox.square(dimension: 40, child: ColoredBox(color: Color(0xFFFFFFFF))),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    concealed = !reducedMotion && status.value == MorphTagStatus.pending;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        translation = !reducedMotion && status.value == MorphTagStatus.unmatched
            ? Offset(0, 200 * (1 - animation.value))
            : Offset.zero;
        return Transform.translate(
          offset: translation,
          child: IgnorePointer(
            ignoring: concealed,
            child: Opacity(opacity: concealed ? 0 : 1, child: child),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    status.removeListener(changedInternalState);
    super.dispose();
  }
}
