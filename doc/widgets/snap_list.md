# SnapList

`SnapList` moves between adjacent items with a swipe, keyboard command, or
controller action. Use it for paged feeds, galleries, or cards that should
settle at a predictable position. It supplies interaction without adding
colors, indicators, or other app styling.

You can build a TikTok-style feed: each item fills the viewport, and swiping
up or down moves to the next or previous item. Use `SnapList.builder` with
`axis: Axis.vertical` and `viewportFraction: 1` (both defaults), and give the
list the available screen space. Supply your own videos, cards, and controls;
video playback remains the app's responsibility.

Import `package:oh_my_flutter/oh_my_flutter.dart` and provide a bounded width
and height.

## Choose how children are created

```dart
SizedBox(
  height: 240,
  child: SnapList(
    axis: Axis.horizontal,
    viewportFraction: 0.85,
    spacing: 12,
    children: const [
      Center(child: Text('First card')),
      Center(child: Text('Second card')),
    ],
  ),
)
```

The normal constructor mounts every child and retains its state until the
child is removed. Use it for small collections.

For larger collections, build items lazily:

```dart
SnapList.builder(
  itemCount: entries.length,
  itemBuilder: (context, index) => EntryCard(
    key: ValueKey(entries[index].id),
    entry: entries[index],
  ),
)
```

Lazy children outside the visible and prepared range may be disposed. Use
Flutter's `AutomaticKeepAliveClientMixin` when particular children must retain
state. Appending items preserves existing positions. Lazy lists do not track
item identity across reorderings or insertions before existing items.

## Size and motion

`axis` defaults to vertical. `viewportFraction` sets the uniform item size as
a fraction of the viewport after padding. A fraction below one reveals nearby
items; `spacing` adds a gap without reducing the item size. Items settle at
`alignment`, which defaults to center. Start/end respect the
horizontal reading direction. Safe-area spacing remains the caller's choice.

Every drag or fling advances at most one item. Nested content scrolls normally
and transfers the same drag to the list when it reaches an edge with an
adjacent target. Mouse dragging follows Flutter's inherited device policy;
wheel, trackpad, keyboard, and accessibility scrolling are supported.

Set `commitThreshold` and motion settings directly on
`SnapList`. Curves default to linear; select easing explicitly, for example:

```dart
SnapList(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeOutCubic,
  children: cards,
)
```

`curve` and `duration` apply to forward movement.
`reverseCurve` and `reverseDuration` apply to previous-item navigation, backward
swipes, and returning after a cancelled drag. When omitted, they use `curve` and
`duration`, respectively. Set them only when the return should feel different.
Reduced motion changes items without
animated travel.

## Observe and navigate

Attach a `SnapListController` to one list, then use `next()` or `previous()`.
Their futures complete true when the adjacent real item settles, or false
when unavailable, interrupted, or settled on trailing content. Appending items
while trailing content is shown can advance the list afterward. Dispose the controller when finished.

The controller is listenable. `index` changes when an item settles and stays
at the last real item while trailing content is shown. `position` is continuous,
with integer values at item anchors. Empty lists have no index or position.
`isMoving` excludes stationary trailing content.

Use `onIndexChanged` for completed item changes. Initial mounting does not
emit an item-change callback. A new gesture or controller action interrupts
movement from its current position.

## Trailing content

Use `trailingBuilder` for content revealed after the last item: a loading
indicator, retry button, end message, or another widget of your choice.
Trailing content has no item index.

```dart
SnapList.builder(
  itemCount: entries.length,
  itemBuilder: (context, index) => EntryCard(entry: entries[index]),
  onIndexChanged: (index) {
    if (index >= entries.length - 2 && !isLoading && hasMore) {
      fetchMore();
    }
  },
  trailingBuilder: (context) => SizedBox(
    height: 96,
    child: Center(
      child: loadError != null
          ? TextButton(onPressed: fetchMore, child: const Text('Try again'))
          : Text(hasMore ? 'Loading…' : 'All caught up'),
    ),
  ),
)
```

The app decides when to fetch, prevents duplicate requests, handles errors,
and appends items. SnapList does not know whether trailing content represents
loading, an error, or a permanent footer.

### Choose the reveal size

The trailing child's measured size along `axis` determines how far the last
item moves. It receives loose constraints along that axis, up to the padded
viewport size, and fills the cross axis. A small child produces a small reveal.
Use `SizedBox.expand(child: ...)` to fill the viewport and fully move past the
last item. For a naturally sized column, use `mainAxisSize: MainAxisSize.min`.
A `LayoutBuilder` inside the trailing builder can read the available size.

A bare `Expanded` is not valid here; it requires a `Row` or `Column` parent.
Omit `trailingBuilder` or return `SizedBox.shrink()` for no reveal. With no
items, trailing content starts at the viewport's leading edge.

### Append while trailing content is visible

Once the user commits a swipe to trailing content, appending items advances
to the **first newly appended item**, including during the reveal animation.
Only one item is advanced, regardless of how many arrive. Returning to an item
or cancelling a drag cancels that automatic advance. Appending elsewhere
preserves the selected item.

Changes to trailing content alone do not advance the list. If its measured
size changes while shown, the reveal adjusts to fit; removing it returns to
the last item. These transitions respect reduced motion.

See the [API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/SnapList-class.html)
for all constructor and member contracts.
