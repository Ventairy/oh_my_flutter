part of 'morph.dart';

final class _MorphGroupCapture extends ChangeNotifier {
  new(this.link, this.snapshot, this.reference) : revision = GroupCaptureAccess.revision(link, reference);
  final RenderBox reference;
  int? revision;
  bool get isCurrent => revision == GroupCaptureAccess.revision(link, reference);
  final GroupLink link;
  GroupSnapshot snapshot;

  GroupSnapshot? captureReplacement() => _MorphSnapshotCapture.captureGroup(
    link,
    relativeTo: reference,
    bounds: snapshot.bounds,
    pixelRatio: _pixelRatio,
  );

  double _pixelRatio = 1;

  void replaceSnapshot(GroupSnapshot value) {
    final previous = snapshot;
    snapshot = value;
    revision = GroupCaptureAccess.revision(link, reference);
    notifyListeners();
    SchedulerBinding.instance.addPostFrameCallback((_) => previous.dispose());
    SchedulerBinding.instance.ensureVisualUpdate();
  }

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

  @override
  void dispose() {
    assert(_presentations == 0, 'Release presentations before disposing a group capture.');
    snapshot.dispose();
    super.dispose();
  }
}
