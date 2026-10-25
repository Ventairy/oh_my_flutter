part of 'contour.dart';

class _ContourColoredBoxSource {
  new(BuildContext owner) : _owner = WeakReference(owner);

  final WeakReference<BuildContext> _owner;
  WeakReference<RenderObjectElement>? _element;

  ColoredBox? widgetFor(RenderBox source, _RenderContourCapture capture) {
    if (!capture.attached) return null;
    final owner = _owner.target;
    if (owner is! SingleChildRenderObjectElement || !owner.mounted || !identical(owner.renderObject, capture)) {
      return null;
    }
    final cached = _element?.target;
    if (cached != null) {
      final widget = _matchingWidget(cached, source);
      if (widget != null) return widget;
    }

    Element? node = owner;
    for (var depth = 0; node != null && depth < 64; depth++) {
      if (node is RenderObjectElement) {
        final widget = _matchingWidget(node, source);
        if (widget != null) {
          _element = WeakReference(node);
          return widget;
        }
      }
      // These exact framework elements own at most one child. Reject other
      // element kinds before visiting, keeping wide or custom subtrees bounded.
      if (!const <Type>{
        SingleChildRenderObjectElement,
        StatelessElement,
        StatefulElement,
        InheritedElement,
      }.contains(node.runtimeType)) {
        return null;
      }
      Element? next;
      node.visitChildElements((child) => next = child);
      node = next;
    }
    return null;
  }

  ColoredBox? _matchingWidget(RenderObjectElement element, RenderBox source) {
    if (!element.mounted || !identical(element.renderObject, source)) return null;
    final widget = element.widget;
    return widget is ColoredBox && widget.runtimeType == ColoredBox ? widget : null;
  }
}
