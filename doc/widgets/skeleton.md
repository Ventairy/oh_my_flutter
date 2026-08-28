# Skeleton

`Skeleton` keeps a widget subtree in place while replacing its painted content
with neutral loading shapes. On each branch, layout-only widgets are traversed
until the first descendant paints visible content. That descendant becomes the
bone and its children are omitted. A decorated avatar containing an icon, for
example, becomes one complete avatar bone. Use it when the final layout is
already known and the content will appear in that same space.

```dart
import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

const placeholder = Skeleton(
  semanticsLabel: 'Loading contact', // Localize this label in the app.
  style: SkeletonStyle(
    radius: Radius.circular(8),
    effect: SkeletonShimmerEffect(),
  ),
  child: ListTile(
    leading: CircleAvatar(),
    title: Text('Loading title'),
    subtitle: Text('Loading description'),
  ),
);
```

Customize a branch with `SkeletonDescendant`:

```dart
SkeletonDescendant(
  behavior: SkeletonDescendantBehavior.deferToChildren,
  child: CircleAvatar(
    child: Icon(Icons.person),
  ),
)
```

Choose the behavior that matches the loading design:

- `paintAsBone` makes the first visibly painted descendant the bone and omits
  its children. If nothing paints, the annotated layout bounds become a bone.
- `deferToChildren` skips the first visibly painted level and skeletonizes the
  branches below it. In the example above, the avatar surface is omitted and
  the icon becomes the bone.
- `hide` omits the complete subtree while retaining its layout space.

Annotations can be nested to build more detailed placeholders. A
`deferToChildren` annotation allows deeper annotations to apply. `paintAsBone`
and `hide` finish their branch, so nested annotations below either behavior do
not apply. There is no nesting limit.

Outside an enabled ancestor `Skeleton`, every annotation is a no-op and the
original subtree renders normally.

The default style uses a neutral gray fill, a four-pixel Material-style radius,
and no animation. Choose `SkeletonShimmerEffect` for a moving highlight or
`SkeletonFadeEffect` for a gentle opacity cycle. Colors, rectangular-bone
radius, animation duration, opacity, and shimmer direction can be configured
through the style and effect objects.

While enabled, `Skeleton` removes its child's pointer, focus, and semantics
behavior so hidden controls cannot be used accidentally. Set `semanticsLabel`
to a localized description of the pending content, such as “Loading contact”.
It becomes the region's single live loading status. If a parent already owns
that status, omit the label here to avoid duplicate announcements.

Wrap one `Skeleton` around a related placeholder subtree when its loading state
changes as a unit. Use separate Skeletons for sections that load independently;
each animated wrapper adds rendering work.

A descendant `RepaintBoundary` is intentionally represented by one rectangular
bone so its retained subtree does not have to be replayed. List and grid
delegates commonly insert these boundaries around items. Wrap a boundary in a
`deferToChildren` annotation when its internal branches should become separate
bones instead. Putting `Skeleton` inside each item boundary is also suitable
when each item owns its loading state. Prefer the per-item form for long
scrolling collections.

Set `enabled` to `false` to show the child normally. When the platform requests
reduced motion, animated effects stop and the neutral static skeleton remains
visible.
