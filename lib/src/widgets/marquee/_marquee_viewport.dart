part of 'marquee.dart';

class _MarqueeViewport extends MultiChildRenderObjectWidget {
  const _MarqueeViewport({
    required this.animation,
    required this.direction,
    required this.spacing,
    required this.width,
    required this.height,
    required this.staticPosition,
    required this.interactive,
    required this.infinity,
    required this.sourceChildCount,
    required this.onRequiredChildCountChanged,
    required super.children,
  });

  final Animation<double> animation;
  final MarqueeDirection direction;
  final double spacing;
  final double? width;
  final double? height;
  final bool staticPosition;
  final bool interactive;
  final bool infinity;
  final int sourceChildCount;
  final void Function(int) onRequiredChildCountChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMarquee(
      animation: animation,
      direction: direction,
      spacing: spacing,
      width: width,
      height: height,
      staticPosition: staticPosition,
      interactive: interactive,
      infinity: infinity,
      sourceChildCount: sourceChildCount,
      onRequiredChildCountChanged: onRequiredChildCountChanged,
    );
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderMarquee renderObject) {
    renderObject
      ..animation = animation
      ..direction = direction
      ..spacing = spacing
      ..width = width
      ..height = height
      ..staticPosition = staticPosition
      ..interactive = interactive
      ..infinity = infinity
      ..sourceChildCount = sourceChildCount
      .._onRequiredChildCountChanged = onRequiredChildCountChanged;
  }
}
