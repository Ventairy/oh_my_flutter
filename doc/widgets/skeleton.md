# Skeleton

`Skeleton` keeps a widget subtree in place while replacing its painted leaf
content with neutral loading shapes. Text, images, icons, and leaf custom
paintings become bones, while structural surfaces such as card backgrounds
remain visible. Use it when the final layout is already known and the content
will appear in that same space.

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
delegates commonly insert these boundaries around items. Put `Skeleton` inside
each item boundary when its internal leaf shapes should remain visible, or
disable automatically added repaint boundaries for a small bounded collection.
Prefer the per-item form for long scrolling collections.

Set `enabled` to `false` to show the child normally. When the platform requests
reduced motion, animated effects stop and the neutral static skeleton remains
visible.
