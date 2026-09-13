part of 'maybe_safe_area.dart';

/// Measures how much of a region overlaps the device's unsafe edges.
///
/// Use the required [handle] to coordinate content inside a fixed surface.
/// This widget does not move, pad, clip, or consume MediaQuery padding. Observe
/// the surface around a scrolling viewport rather than its moving content.
///
/// See the [SafeAreaObserver guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/safe_area_observer.md).
class SafeAreaObserver extends SingleChildRenderObjectWidget {
  /// Observes the enabled unsafe edges of [child].
  const SafeAreaObserver({
    required this.handle,
    required super.child,
    this.left = true,
    this.top = true,
    this.right = true,
    this.bottom = true,
    super.key,
  });

  /// Receives measurements; its owner must dispose it when no longer needed.
  ///
  /// A handle supports one attached observer at a time.
  final SafeAreaObserverHandle handle;

  /// Whether to measure overlap with the left unsafe edge.
  final bool left;

  /// Whether to measure overlap with the top unsafe edge.
  final bool top;

  /// Whether to measure overlap with the right unsafe edge.
  final bool right;

  /// Whether to measure overlap with the bottom unsafe edge.
  final bool bottom;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSafeAreaObserver(
    handle: handle,
    padding: MediaQuery.paddingOf(context),
    viewSize: MediaQuery.sizeOf(context),
    edges: (left: left, top: top, right: right, bottom: bottom),
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderSafeAreaObserver)
      ..handle = handle
      ..configure(
        padding: MediaQuery.paddingOf(context),
        viewSize: MediaQuery.sizeOf(context),
        edges: (left: left, top: top, right: right, bottom: bottom),
      );
  }
}
