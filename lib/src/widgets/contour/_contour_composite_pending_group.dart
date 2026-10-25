part of 'contour.dart';

// Shares only pending work. No completed pictures or source trees are cached.
class _ContourCompositePendingGroup {
  new _(this._key);

  static final _pending = <Object, _ContourCompositePendingGroup>{};
  final Object _key;
  final _members = <Completer<ContourCompositeResult?>>{};
  final _cancelled = Completer<void>();
  bool _closed = false;

  static Future<ContourCompositeResult?> capture({
    required Object? key,
    required Future<void> cancelled,
    required Future<ContourCompositeResult?> Function(Future<void> cancelled) create,
  }) {
    if (key == null) return create(cancelled);
    final pending = _pending[key];
    if (pending != null) return pending._subscribe(cancelled);
    if (_pending.length >= _ContourNativeTextCache._maximumEntries) return create(cancelled);
    final group = _ContourCompositePendingGroup._(key);
    _pending[key] = group;
    final response = group._subscribe(cancelled);
    try {
      unawaited(
        create(group._cancelled.future).then<void>(
          group._finish,
          onError: (Object _, StackTrace _) {
            group._finish(null);
          },
        ),
      );
    } catch (_) {
      group._finish(null);
    }
    return response;
  }

  Future<ContourCompositeResult?> _subscribe(Future<void> cancelled) {
    final member = Completer<ContourCompositeResult?>();
    _members.add(member);
    unawaited(
      cancelled.then<void>((_) {
        if (_closed || !_members.remove(member)) return;
        member.complete(null);
        if (_members.isEmpty) {
          _closed = true;
          _remove();
          _cancelled.complete();
        }
      }),
    );
    return member.future;
  }

  void _remove() {
    if (identical(_pending[_key], this)) _pending.remove(_key);
  }

  void _finish(ContourCompositeResult? value) {
    _remove();
    _closed = true;
    try {
      for (final member in _members) {
        if (value == null) {
          member.complete(null);
          continue;
        }
        ui.Picture? picture;
        try {
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawPicture(value.picture);
          picture = recorder.endRecording();
          member.complete(
            ContourCompositeResult(
              picture: picture,
              boundsPx: value.boundsPx,
              sourceTouchesBoundary: value.sourceTouchesBoundary,
            ),
          );
        } catch (_) {
          picture?.dispose();
          member.complete(null);
        }
      }
    } finally {
      _members.clear();
      value?.dispose();
    }
  }
}
