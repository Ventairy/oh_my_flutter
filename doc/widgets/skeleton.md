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
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
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
  behavior: const SkeletonDescendantBehavior.deferToChildren(),
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

To draw one branch yourself, supply a `builder` to `paintAsBone`:

```dart
Skeleton(
  child: Row(
    children: [
      SkeletonDescendant(
        behavior: SkeletonDescendantBehavior.paintAsBone(
          builder: (context) => const ColoredBox(color: Colors.blue),
        ),
        child: const SizedBox(width: 80, height: 40),
      ),
      const Expanded(child: Text('Loading title')),
    ],
  ),
)
```

The builder's widget fills the annotated child's space while loading. It is
shown exactly as supplied; the skeleton's color, shape, and effect do not
style it. The original child stays mounted, and other branches still produce
automatic bones. The builder is used only while an ancestor `Skeleton` is
enabled. Its widget shares the skeleton's paused ticker mode while loading;
use an external animation owner for motion that must continue during loading.

Annotations can be nested to build more detailed placeholders. A
`deferToChildren` annotation allows deeper annotations to apply. `paintAsBone`
and `hide` finish their branch, so nested annotations below either behavior do
not apply. There is no nesting limit.

Outside an enabled ancestor `Skeleton`, every annotation is a no-op and the
original subtree renders normally.

The default style uses a neutral gray fill, a rounded-rectangle shape with a four-pixel radius,
and no animation. Choose `SkeletonShimmerEffect` for a moving highlight or
`SkeletonFadeEffect` for a gentle opacity cycle. Colors, rectangular-bone
shape, animation duration, opacity, and shimmer direction can be configured
through the style and effect objects.
Use a bounds-aware `ShapeBorder`, such as `StadiumBorder`, when each bone should
form a capsule regardless of its size. Design-system shapes can be passed the
same way.

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

## Switching between loading and content

The switch is immediate by default. Add a crossfade to gently reveal content
when loading finishes and restore the skeleton when loading starts again:

```dart
Skeleton(
  enabled: isLoading,
  transition: .crossfade(duration: const Duration(milliseconds: 250)),
  child: const ProfileCard(),
)
```

The crossfade keeps the child mounted, so its local state survives the switch.
Use `.custom` when the outgoing and incoming appearances need a different
visual treatment:

```dart
Skeleton(
  enabled: isLoading,
  transition: .custom(
    transitionBuilder: (outgoing, incoming, animation) => Stack(
      children: [
        FadeTransition(opacity: ReverseAnimation(animation), child: outgoing),
        FadeTransition(opacity: animation, child: incoming),
      ],
    ),
  ),
  child: const ProfileCard(),
)
```

Include `incoming` exactly once in the returned widget tree. Choose transition
widgets that preserve the incoming child's interaction and accessibility when
it becomes visible. A custom transition captures the outgoing appearance as an
image, so it stays still during the switch and uses memory based on the
region's size. The incoming child remains live.
Transitions start only when `enabled` changes, and reduced motion makes the
switch immediate.
