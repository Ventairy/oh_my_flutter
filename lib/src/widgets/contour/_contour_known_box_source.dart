part of 'contour.dart';

class _ContourKnownBoxSource {
  // One rect/RRect/ellipse has at most 10 verbs, 13 points and four conic
  // weights. The accepted affine transform cannot add segments. This 4 KiB
  // allowance covers its copied Path wrappers, coordinate storage and bounded
  // identity-key metadata; it is not an exact native allocation measurement.
  // A shadow key's source reference is only the final Path, never the widget,
  // decoration or descriptor key.
  // Atlas recordings charge this allowance for every frame, in addition to
  // Picture.approximateBytesUsed.
  static const int sourceBytes = 4096;

  static bool supports(RenderDecoratedBox source) {
    if (source.runtimeType != RenderDecoratedBox || !_isEmptyLayoutRenderTree(source.child)) return false;
    return supportsDecoration(source.decoration);
  }

  // Container inserts empty padding even when its public child is null. These
  // exact layout-only classes paint and expose semantics only through a child;
  // accepting a general proxy or an unrecognized descendant would be unsafe.
  static bool _isEmptyLayoutRenderTree(RenderBox? root) {
    var node = root;
    while (node != null) {
      if (node.runtimeType == RenderPadding) {
        node = (node as RenderPadding).child;
      } else if (node.runtimeType == RenderLimitedBox) {
        node = (node as RenderLimitedBox).child;
      } else if (node.runtimeType == RenderConstrainedBox) {
        node = (node as RenderConstrainedBox).child;
      } else {
        return false;
      }
    }
    return true;
  }

  static bool _isEmptyLayoutWidget(Widget? root) {
    var node = root;
    while (node != null) {
      if (!const <Type>{Padding, LimitedBox, ConstrainedBox, SizedBox}.contains(node.runtimeType)) return false;
      node = (node as SingleChildRenderObjectWidget).child;
    }
    return true;
  }

  static bool supportsColor(Color color) =>
      const <Type>{Color, MaterialColor, MaterialAccentColor}.contains(color.runtimeType) && color.a == 1;

  static const _rectangle = BoxDecoration(color: Color(0xffffffff));

  static bool supportsDecoration(Decoration decoration) {
    if (decoration.runtimeType != BoxDecoration) return false;
    final box = decoration as BoxDecoration;
    final color = box.color;
    final radius = box.borderRadius;
    if (radius != null &&
        !const <Type>{
          BorderRadius,
          BorderRadiusDirectional,
        }.contains(radius.runtimeType)) {
      return false;
    }
    if (box.shape == BoxShape.circle && radius != null) return false;
    return color != null &&
        supportsColor(color) &&
        box.image == null &&
        box.gradient == null &&
        box.border == null &&
        (box.boxShadow == null || box.boxShadow!.isEmpty) &&
        (box.backgroundBlendMode == null || box.backgroundBlendMode == BlendMode.srcOver);
  }

  static Object? keyFor(_RenderContourCapture capture) => _find(capture)?.$5;

  static _ContourDeclaredSource? resolve(_RenderContourCapture capture) {
    final found = _find(capture);
    if (found == null) return null;
    final (source, box, textDirection, matrix, key) = found;
    final rect = Offset.zero & source.size;
    final path = Path();
    switch (box.shape) {
      case BoxShape.circle:
        path.addOval(
          Rect.fromCircle(
            center: rect.center,
            radius: source.size.shortestSide / 2,
          ),
        );
      case BoxShape.rectangle:
        final radius = box.borderRadius;
        if (radius == null) {
          path.addRect(rect);
        } else {
          if (radius is! BorderRadius && textDirection == null) return null;
          final resolved = radius.resolve(textDirection);
          final radii = [
            resolved.topLeft,
            resolved.topRight,
            resolved.bottomLeft,
            resolved.bottomRight,
          ];
          if (radii.any(
            (r) => !r.x.isFinite || !r.y.isFinite || r.x < 0 || r.y < 0,
          )) {
            return null;
          }
          path.addRRect(resolved.toRRect(rect));
        }
    }
    final transformed = path.transform(matrix.storage);
    if (!transformed.getBounds().isFinite) return null;
    return _ContourDeclaredSource(
      transformed,
      key,
      knownBox: _ContourKnownBoxGeometry.resolve(source, box, textDirection, matrix),
    );
  }

  static (RenderBox, BoxDecoration, TextDirection?, Matrix4, Object)? _admit(
    RenderBox source,
    BoxDecoration decoration,
    TextDirection? textDirection,
    _RenderContourCapture capture,
  ) {
    if (!source.hasSize || !source.size.isFinite || source.size.isEmpty) return null;
    final captureBounds = capture.paintBounds;
    // Keep this optimization inside the region guaranteed to retain at
    // least 3x capture sampling, including its one-pixel border padding.
    // Larger bounds retain the ordinary sampled visibility decision.
    if (!captureBounds.isFinite ||
        captureBounds.shortestSide < 1 ||
        captureBounds.width * captureBounds.height > _RenderContour._maximumPixels / 16) {
      return null;
    }
    final matrix = source.getTransformTo(capture);
    final t = matrix.storage;
    if (!_ContourDeclaredSource._isSupportedTransform(t)) return null;
    final determinant = t[0] * t[5] - t[1] * t[4];
    final norm = t[0] * t[0] + t[1] * t[1] + t[4] * t[4] + t[5] * t[5];
    if (determinant == 0 || !determinant.isFinite || !norm.isFinite) return null;
    final largest = math.sqrt(
      (norm +
              math.sqrt(
                math.max(0, norm * norm - 4 * determinant * determinant),
              )) /
          2,
    );
    final smallest = determinant.abs() / largest;
    // A one-logical-pixel inscribed diameter leaves a large margin over
    // the captured .25 logical alpha-area and .03 per-pixel noise gates.
    // Thin or tiny boxes keep the ordinary sampled visibility decision.
    if (!smallest.isFinite || smallest * source.size.shortestSide < 1) return null;
    return (
      source,
      decoration,
      textDirection,
      matrix,
      (
        decoration,
        textDirection,
        source.size,
        t[0],
        t[1],
        t[4],
        t[5],
        t[12],
        t[13],
      ),
    );
  }

  static (RenderBox, BoxDecoration, TextDirection?, Matrix4, Object)? _find(
    _RenderContourCapture capture,
  ) {
    var node = capture.child;
    while (node != null) {
      if (node.runtimeType == RenderDecoratedBox) {
        final source = node as RenderDecoratedBox;
        if (!supports(source)) return null;
        return _admit(source, source.decoration as BoxDecoration, source.configuration.textDirection, capture);
      }
      final type = node.runtimeType;
      if (type == RenderFittedBox) {
        if ((node as RenderFittedBox).clipBehavior != Clip.none) return null;
      } else if (type == RenderTransform) {
        if ((node as RenderTransform).filterQuality != null) return null;
      } else if (!const <Type>{
        RenderSemanticsAnnotations,
        RenderExcludeSemantics,
        RenderConstrainedBox,
        RenderConstrainedOverflowBox,
        RenderPositionedBox,
        RenderPadding,
        RenderIgnorePointer,
        RenderAbsorbPointer,
        RenderRepaintBoundary,
      }.contains(type)) {
        if (node is! RenderProxyBox) return null;
        final colored = capture._coloredBoxSource.widgetFor(node, capture);
        if (colored == null ||
            !colored.isAntiAlias ||
            !supportsColor(colored.color) ||
            !_isEmptyLayoutRenderTree(node.child)) {
          return null;
        }
        return _admit(node, _rectangle, null, capture);
      }
      if (node is RenderProxyBox) {
        node = node.child;
      } else if (node is RenderShiftedBox) {
        node = node.child;
      } else {
        return null;
      }
    }
    return null;
  }
}
