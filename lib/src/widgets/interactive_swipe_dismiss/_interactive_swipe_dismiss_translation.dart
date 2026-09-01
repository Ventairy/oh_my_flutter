part of 'interactive_swipe_dismiss.dart';

class _InteractiveSwipeDismissTranslation extends SingleChildRenderObjectWidget {
  const _InteractiveSwipeDismissTranslation({
    required this.controller,
    required super.child,
  });

  final _InteractiveSwipeDismissTranslationController controller;

  @override
  _RenderInteractiveSwipeDismissTranslation createRenderObject(
    BuildContext context,
  ) {
    return _RenderInteractiveSwipeDismissTranslation(controller);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderInteractiveSwipeDismissTranslation renderObject,
  ) {
    renderObject.updateController(controller);
  }
}
