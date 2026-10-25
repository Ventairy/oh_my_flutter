part of 'contour.dart';

class _ContourCapture extends SingleChildRenderObjectWidget {
  const new({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderContourCapture(context);
}
