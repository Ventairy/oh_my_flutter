part of 'contour.dart';

class _ContourPictureDecorationLayer extends _ContourDecorationLayer implements ContourLayerSnapshotContent {
  ui.Picture? _picture;
  Offset _offset = Offset.zero;
  Object? _sourceIdentity;
  int _sourceRevision = -1;

  @override
  bool get snapshotIsCurrent => isCurrent();
  @override
  Offset get snapshotChildOffset => Offset.zero;
  @override
  ui.Picture? get snapshotPicture => _picture;
  @override
  Offset get snapshotPictureOffset => _offset;

  void configure({
    required ui.Picture? picture,
    required Offset offset,
    required Object? sourceIdentity,
    required int sourceRevision,
  }) {
    _invalidateSubmission();
    _sourceIdentity = sourceIdentity;
    _sourceRevision = sourceRevision;
    _picture?.dispose();
    _picture = picture;
    _offset = offset;
    markNeedsAddToScene();
  }

  @override
  bool addDecorationToScene(ui.SceneBuilder builder) {
    final picture = _picture;
    if (picture == null) return false;
    builder.addPicture(_offset, picture);
    return true;
  }

  @override
  void dispose() {
    _picture?.dispose();
    _picture = null;
    super.dispose();
  }
}
