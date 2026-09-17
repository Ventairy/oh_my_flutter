part of 'group.dart';

/// An owned, immutable capture of a group's combined visual content.
///
/// Paint it repeatedly or export an image. It remains usable after the original
/// members unmount. Call [dispose] when finished.
final class GroupSnapshot {
  GroupSnapshot._(this.bounds, this._snapshot, this._pixelRatio) {
    _snapshot.retain();
  }

  /// The captured rectangle in the reference widget's coordinate system.
  final Rect bounds;
  final RasterSnapshot _snapshot;
  final double _pixelRatio;
  bool _disposed = false;

  /// Logical dimensions of the captured rectangle.
  Size get size => bounds.size;

  /// Paints the composition with its top-left corner at [offset].
  void paint(Canvas canvas, Offset offset) {
    assert(!_disposed, 'A disposed GroupSnapshot cannot be painted.');
    _snapshot.paint(canvas, offset);
  }

  /// Exports the composition at its captured pixel ratio.
  ///
  /// The caller owns the returned image and must dispose it separately.
  Future<ui.Image> toImage() async {
    assert(!_disposed, 'A disposed GroupSnapshot cannot be exported.');
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_pixelRatio);
    paint(canvas, Offset.zero);
    final picture = recorder.endRecording();
    try {
      return await picture.toImage((size.width * _pixelRatio).ceil(), (size.height * _pixelRatio).ceil());
    } finally {
      picture.dispose();
    }
  }

  /// Releases this snapshot's captured resources. Safe to call more than once.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _snapshot.release();
  }
}
