part of 'morph.dart';

final class _MorphGroupCapture {
  new(this.link, this.snapshot, this.reference, this.revision);
  final RenderBox reference;
  final int? revision;
  int? get currentRevision => GroupCaptureAccess.revision(link, reference);
  bool get isCurrent => revision == GroupCaptureAccess.revision(link, reference);
  final GroupLink link;
  final GroupSnapshot snapshot;

  int _presentations = 0;

  VoidCallback beginPresentation(_MorphVisibilityHandle? visibility) {
    GroupPresentationLease? lease;
    void update() {
      if (visibility == null || visibility.hidden) {
        lease ??= GroupCaptureAccess.hide(link);
      } else {
        lease?.release();
        lease = null;
      }
    }

    visibility?.addListener(update);
    update();
    _presentations++;
    var released = false;
    return () {
      if (released) return;
      released = true;
      visibility?.removeListener(update);
      lease?.release();
      _presentations--;
    };
  }

  void dispose() {
    assert(_presentations == 0, 'Release presentations before disposing a group capture.');
    snapshot.dispose();
  }
}
