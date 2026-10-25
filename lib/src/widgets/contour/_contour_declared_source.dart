part of 'contour.dart';

class _ContourDeclaredSource {
  new(this.path, this.key, {this.knownBox});
  final Path path;
  final Object key;
  final _ContourKnownBoxGeometry? knownBox;

  // Child render objects are not mounted when their parent attaches. Defer
  // eager worker startup only when this widget tree already declares a source;
  // the laid-out render tree still determines whether it can actually be used.
  static bool canDeferPrewarm(Widget child) {
    var node = child;
    while (true) {
      final type = node.runtimeType;
      if (type == Container) {
        final source = node as Container;
        final decoration = source.decoration;
        final color = source.color;
        final supportedFill = decoration != null
            ? color == null && _ContourKnownBoxSource.supportsDecoration(decoration)
            : color != null && source.isAntiAlias && _ContourKnownBoxSource.supportsColor(color);
        return supportedFill &&
            source.foregroundDecoration == null &&
            source.alignment == null &&
            source.clipBehavior == Clip.none &&
            (source.transform == null || _isSupportedTransform(source.transform!.storage)) &&
            _ContourKnownBoxSource._isEmptyLayoutWidget(source.child);
      }
      if (type == ColoredBox) {
        final source = node as ColoredBox;
        return source.isAntiAlias &&
            _ContourKnownBoxSource.supportsColor(source.color) &&
            _ContourKnownBoxSource._isEmptyLayoutWidget(source.child);
      }
      if (type == DecoratedBox) {
        final source = node as DecoratedBox;
        return _ContourKnownBoxSource._isEmptyLayoutWidget(source.child) &&
            _ContourKnownBoxSource.supportsDecoration(source.decoration);
      }
      if (type == FittedBox) {
        if ((node as FittedBox).clipBehavior != Clip.none) return false;
      } else if (type == Transform) {
        final source = node as Transform;
        if (source.filterQuality != null || !_isSupportedTransform(source.transform.storage)) return false;
      } else if (!const <Type>{
        Semantics,
        ExcludeSemantics,
        SizedBox,
        ConstrainedBox,
        OverflowBox,
        Align,
        Center,
        Padding,
        IgnorePointer,
        AbsorbPointer,
        RepaintBoundary,
      }.contains(type)) {
        return false;
      }
      final next = (node as SingleChildRenderObjectWidget).child;
      if (next == null) return false;
      node = next;
    }
  }

  static bool _isSupportedTransform(Float64List transform) =>
      transform.every((value) => value.isFinite) &&
      const [
        2,
        3,
        6,
        7,
        8,
        9,
        11,
        14,
      ].every((index) => transform[index] == 0) &&
      transform[10] == 1 &&
      transform[15] == 1 &&
      transform[0] * transform[5] - transform[1] * transform[4] != 0;

  bool isCurrent(_RenderContourCapture capture) => _ContourKnownBoxSource.keyFor(capture) == key;

  static _ContourDeclaredSource? resolve(_RenderContourCapture capture) => _ContourKnownBoxSource.resolve(capture);
}
