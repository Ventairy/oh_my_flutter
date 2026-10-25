part of 'contour.dart';

class _ContourRenderWidget extends SingleChildRenderObjectWidget {
  const new({
    required this.color,
    required this.controller,
    required this.prepareWhenHidden,
    required this.source,
    required this.amount,
    required this.shadows,
    required this.pixelRatio,
    required this.deferPrewarm,

    required super.child,
  });

  final Color color;
  final ContourController? controller;
  final bool prepareWhenHidden;
  final Widget source;
  final double amount;
  final List<Shadow> shadows;
  final double pixelRatio;
  final bool deferPrewarm;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderContour(
    color: color,
    controller: controller,
    prepareWhenHidden: prepareWhenHidden,
    source: source,
    amount: amount,
    shadows: shadows,
    pixelRatio: pixelRatio,
    deferPrewarm: deferPrewarm,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderContour renderObject) {
    renderObject.configure(
      color: color,
      controller: controller,
      prepareWhenHidden: prepareWhenHidden,
      source: source,
      amount: amount,
      shadows: shadows,
      pixelRatio: pixelRatio,
      deferPrewarm: deferPrewarm,
    );
  }
}
