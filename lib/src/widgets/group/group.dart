import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../rendering/snapshot/raster_snapshot.dart';

part '_render_group.dart';
part 'group_capture_access.dart';
part 'group_link.dart';
part 'group_presentation_lease.dart';
part 'group_snapshot.dart';

/// Connects a child to other widgets that should be considered together.
///
/// Share a [GroupLink] between members, even when they have different parents.
/// Group leaves their normal layout, painting, interaction, and semantics intact.
/// See the [Group guide](https://github.com/Ventairy/oh_my_flutter/blob/main/doc/widgets/group.md).
class Group extends SingleChildRenderObjectWidget {
  /// Connects [child] to [link].
  const Group({required this.link, required super.child, this.zIndex = 0, super.key});

  /// The shared connection identifying this child's group.
  final GroupLink link;

  /// Stacking order, with higher values painted above lower values.
  ///
  /// Equal values preserve registration order. This does not change the child's
  /// normal painting or hit testing order. Must be finite.
  final double zIndex;

  @override
  RenderObject createRenderObject(BuildContext context) {
    assert(zIndex.isFinite, 'Group.zIndex must be finite.');
    return _RenderGroup(link, zIndex);
  }

  @override
  void updateRenderObject(BuildContext context, covariant RenderObject renderObject) {
    assert(zIndex.isFinite, 'Group.zIndex must be finite.');
    (renderObject as _RenderGroup)
      ..link = link
      ..zIndex = zIndex;
  }
}
