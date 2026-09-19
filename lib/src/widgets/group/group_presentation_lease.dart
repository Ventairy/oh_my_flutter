part of 'group.dart';

/// Package-internal ownership of a group's temporary presentation suppression.
@internal
final class GroupPresentationLease {
  new _(this._link) {
    _link._leases.add(this);
    _link._members.forEach(_attach);
  }
  final GroupLink _link;
  final Set<_RenderGroup> _members = {};
  bool _released = false;

  void _attach(_RenderGroup member) {
    if (_members.add(member)) member._changeVisibility(1);
  }

  void _detach(_RenderGroup member) {
    if (_members.remove(member)) member._changeVisibility(-1);
  }

  /// Restores originals after the last presentation releases them.
  void release() {
    if (_released) return;
    _released = true;
    _link._leases.remove(this);
    for (final member in _members) {
      member._changeVisibility(-1);
    }
    _members.clear();
  }
}
