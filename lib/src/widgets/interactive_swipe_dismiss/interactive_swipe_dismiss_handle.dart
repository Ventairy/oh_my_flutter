part of 'interactive_swipe_dismiss.dart';

/// Makes the wrapped area a drag handle for [InteractiveSwipeDismiss].
///
/// Wrap a header, toolbar, or any other widget when dragging anywhere within
/// that widget should begin dismissal regardless of descendant scroll position.
/// Taps and cross-axis gestures remain available until movement clearly favors
/// the dismissal direction. This widget does not change the appearance or
/// layout of [child].
class InteractiveSwipeDismissHandle extends StatelessWidget {
  /// Creates a drag handle around [child].
  const InteractiveSwipeDismissHandle({
    required this.child,
    this.hitTestBehavior = HitTestBehavior.translucent,
    super.key,
  });

  /// The widget whose complete bounds can begin dismissal.
  final Widget child;

  /// How the handle participates in pointer hit testing.
  final HitTestBehavior hitTestBehavior;

  @override
  Widget build(BuildContext context) {
    final scope = _InteractiveSwipeDismissScope.maybeOf(context);
    assert(
      scope != null,
      'InteractiveSwipeDismissHandle requires an ancestor '
      'InteractiveSwipeDismiss.',
    );

    final coordinator = scope?.coordinator;
    if (coordinator == null) return child;

    _InteractiveSwipeDismissHandleGestureRecognizer? recognizer;
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerMove: (event) => recognizer?.handleRawPointerMove(event),
      child: RawGestureDetector(
        behavior: hitTestBehavior,
        excludeFromSemantics: true,
        gestures: <Type, GestureRecognizerFactory>{
          _InteractiveSwipeDismissHandleGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<_InteractiveSwipeDismissHandleGestureRecognizer>(
                () {
                  return recognizer = _InteractiveSwipeDismissHandleGestureRecognizer(
                    coordinator: coordinator,
                    debugOwner: this,
                  );
                },
                (value) {
                  recognizer = value;
                  value._coordinator = coordinator;
                },
              ),
        },
        child: child,
      ),
    );
  }
}
