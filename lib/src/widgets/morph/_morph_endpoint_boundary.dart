part of 'morph.dart';

class _MorphEndpointBoundary extends SingleChildRenderObjectWidget {
  const new({
    required this.visibility,
    required this.onRenderObjectReady,
    required this.onPaint,
    required this.onPresented,
    required this.onSnapshotSuppressed,
    required super.child,
    this.shouldSuppressSnapshot,
  });

  final _MorphVisibilityHandle visibility;
  final ValueChanged<_RenderMorphEndpoint> onRenderObjectReady;
  final VoidCallback onPaint;
  final VoidCallback onPresented;
  final VoidCallback onSnapshotSuppressed;
  final bool Function()? shouldSuppressSnapshot;

  @override
  RenderObject createRenderObject(BuildContext context) {
    final renderObject = _RenderMorphEndpoint(
      visibility,
      onPaint,
      onPresented,
      onSnapshotSuppressed,
      shouldSuppressSnapshot,
    );
    onRenderObjectReady(renderObject);
    return renderObject;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMorphEndpoint renderObject,
  ) {
    renderObject
      ..visibility = visibility
      ..onPaint = onPaint
      ..onPresented = onPresented
      ..onSnapshotSuppressed = onSnapshotSuppressed
      ..shouldSuppressSnapshot = shouldSuppressSnapshot;
    onRenderObjectReady(renderObject);
  }
}
