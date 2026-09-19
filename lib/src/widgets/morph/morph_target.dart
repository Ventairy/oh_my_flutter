part of 'morph.dart';

/// Connects a shared visual with the widgets that accompany its appearance.
///
/// Create one target for each appearance and share it between its [Morph] and
/// [MorphSibling] widgets. Give different appearances equal [tag] values so
/// Morph can transition between them. Keep each target stable across rebuilds,
/// usually in the owning State. At most one attached Morph can use a target,
/// alongside any number of siblings. A target needs no disposal.
///
/// See the [Morph guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/morph.md)
/// for setup and examples.
final class MorphTarget {
  /// Creates the association for one appearance of the content matched by [tag].
  new({required this.tag});

  /// Identifies shared content across different appearances.
  ///
  /// Tags match using equality and hash codes, which must remain stable while
  /// the target is used. Targets themselves have separate instance identities.
  final Object tag;

  _MorphState? _owner;

  void _attach(_MorphState owner) {
    assert(
      _owner == null || identical(_owner, owner),
      'A MorphTarget can belong to only one attached Morph. '
      'Create a separate MorphTarget with the same tag for each appearance.',
    );
    _owner = owner;
  }

  void _detach(_MorphState owner) {
    if (identical(_owner, owner)) _owner = null;
  }
}
