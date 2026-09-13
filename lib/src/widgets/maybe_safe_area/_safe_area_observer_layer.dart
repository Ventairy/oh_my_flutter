part of 'maybe_safe_area.dart';

class _SafeAreaObserverLayer extends ContainerLayer {
  _SafeAreaObserverLayer(this.onComposite);

  final VoidCallback onComposite;

  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    if (attached) onComposite();
    addChildrenToScene(builder);
  }
}
