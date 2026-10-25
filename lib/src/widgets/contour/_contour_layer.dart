part of 'contour.dart';

class _ContourLayer extends OffsetLayer implements ContourLayerSnapshotContent {
  new(this.onComposition);

  final VoidCallback onComposition;
  bool capturing = false;
  @override
  bool get snapshotIsCurrent => true;
  @override
  Offset get snapshotChildOffset => offset;
  @override
  ui.Picture? get snapshotPicture => null;
  @override
  Offset get snapshotPictureOffset => Offset.zero;

  @override
  void addToScene(ui.SceneBuilder builder) {
    super.addToScene(builder);
    if (!capturing) onComposition();
  }
}
