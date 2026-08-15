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

The buckets are selected in this order:

| Elapsed time | Callback |
| --- | --- |
| Future time or exactly now | `onNow` |
| Less than 1 second | `onMillisecondsAgo` |
| Less than 1 minute | `onSecondsAgo` |
| Less than 1 hour | `onMinutesAgo` |
| Less than 24 hours | `onHoursAgo` |
| Less than 30 days | `onDaysAgo` |
| Less than 12 completed calendar months | `onMonthsAgo` |
| Otherwise | `onYearsAgo` |

Counts use whole elapsed units. Months and years use completed calendar months,
so the day of the month affects when their count advances.

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

`TimeAgoFallback.finer` tries progressively smaller units and then `onNow`.
`.coarser` tries progressively larger units and never tries `onNow`.
`.bidirectional` tries smaller units first, larger units second, and `onNow`
last. The count is recalculated for every callback that is tried.

The default `.none` uses `onMiss` immediately when the matched callback is
absent or returns `null`. Every fallback mode also uses `onMiss` after it runs
out of candidates. If no reachable callback produces a value and `onMiss` was
not supplied, the call throws `ArgumentError`.

Current time is read through `package:clock`, so applications and tests can pin
the instant without changing production code. `DateTime` comparison keeps
Dart's normal local/UTC and daylight-saving behavior, so use consistent time
zones when calendar boundaries matter.
