# DateTime relative time

Use `DateTime.timeAgo` when presentation depends on elapsed time but the package
should not own your wording or localization. Callbacks determine both the
result type and the value shown to the user.

## Format elapsed time

```dart
final label = publishedAt.timeAgo<String>(
  onNow: () => 'now',
  onMinutesAgo: (count) => '$count min ago',
  onHoursAgo: (count) => '$count hr ago',
  onDaysAgo: (count) => '$count days ago',
  onMiss: () => 'a while ago',
);
```

The callback for the matching elapsed-time bucket is used. Because the method
is generic, callbacks can return a localized string, a number, a presentation
model, or any other consistent type.

## Choose fallback behavior

Use `fallback` when a missing or conditionally null callback should try another
time unit:

```dart
final label = publishedAt.timeAgo<String>(
  onMinutesAgo: (count) => count <= 10 ? '$count min ago' : null,
  onHoursAgo: (count) => '$count hr ago',
  onMiss: () => 'earlier',
  fallback: TimeAgoFallback.coarser,
);
```

`TimeAgoFallback.finer`, `.coarser`, and `.bidirectional` control which supplied
callbacks are considered. The default `.none` uses `onMiss` immediately when
the matched callback is absent.

Current time is read through `package:clock`, so applications and tests can pin
the instant without changing production code. See the
[API reference](https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/DateTimeExtension.html)
for exact buckets and fallback order.
