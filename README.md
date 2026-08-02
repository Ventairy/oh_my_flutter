# oh_my_flutter

[![CI][ci-badge]][ci]
[![License: MIT][license-badge]][license]
[![pub package][pub-badge]][pub]

Small, strongly typed utilities for common Flutter application tasks.

## Installation

Add the latest compatible release from pub.dev:

```console
flutter pub add oh_my_flutter
```

Or add it directly to your `pubspec.yaml`:

```yaml
dependencies:
  oh_my_flutter: ^0.3.2
```

Import the public library wherever you need it:

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';
```

## Quick start

Extensions make common transformations concise while preserving Flutter and
Dart types:

```dart
import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

final accent = const Color(0xFFFF4A4B);
final lighterAccent = accent.lighten(0.12);
final hex = lighterAccent.toHex();
final oklch = lighterAccent.toOklch();
```

## Utilities

### Present relative time

Use `DateTime.timeAgo` when presentation depends on elapsed time but the package
should not own your wording or localization. Callbacks determine both the
result type and the text shown to the user.

```dart
final label = publishedAt.timeAgo<String>(
  onNow: () => 'now',
  onMinutesAgo: (count) => '$count min ago',
  onHoursAgo: (count) => '$count hr ago',
  onDaysAgo: (count) => '$count days ago',
  onMiss: () => 'a while ago',
);
```

Time is read through `package:clock`, so applications and tests can pin the
current instant without changing production code. See the [API reference][api]
for bucketing and fallback behavior.

### Transform colors and work with OKLCH

Use the color extensions for direct Flutter `Color` transformations. Convert
to OKLCH when you need perceptually uniform lightness, chroma, and hue values.

```dart
final base = const Color(0xFFFF4A4B);

final lighter = base.lighten(0.12);
final darker = base.darken(0.12);
final hex = base.toHex();

final oklch = base.toOklch();
final restored = oklch.toColor();
```

The API reference documents supported color spaces, gamut mapping, clamping,
and alpha behavior.

### Classify gesture velocity

Use the `Velocity` extension at a drag boundary when release speed and direction
should help decide whether an interaction completes.

```dart
void handleDragEnd(DragEndDetails details) {
  final shouldDismiss = details.velocity.isSwipeDown();

  if (shouldDismiss) {
    dismiss();
  }
}
```

The methods classify velocity only. The consuming interaction remains
responsible for distance, progress, and whether the action is allowed.

### Control widget visibility

Use `ControlledVisibility` when parent code should show or hide a child while
the application retains control of its visual transition. Without a transition,
visibility changes immediately.

```dart
final visibilityController = ControlledVisibilityController();

ControlledVisibility(
  controller: visibilityController,
  showDuration: const Duration(milliseconds: 240),
  hideDuration: const Duration(milliseconds: 120),
  showTransition: (child, animation) => FadeTransition(
    opacity: CurveTween(curve: Curves.easeOutCubic).animate(animation),
    child: child,
  ),
  hideTransition: (child, animation) => FadeTransition(
    opacity: animation,
    child: child,
  ),
  child: const Text('More details'),
);

visibilityController.show();
visibilityController.hide();
```

Set `unmount: true` when hidden content should be disposed instead of retaining
its state and layout. Timing, lifecycle, callback, and reduced-motion behavior
are documented in the [API reference][api].

### Show widgets in sequence

Use `Sequence` for an ordered flow that displays one child at a time. Its
controller supports sequential movement and indexed navigation, and exposes
the selected index for controls and progress indicators.

```dart
final sequenceController = SequenceController();

Sequence(
  controller: sequenceController,
  alignment: AlignmentDirectional.topStart,
  nextTransition: (child, animation) => FadeTransition(
    opacity: animation,
    child: child,
  ),
  previousTransition: (child, animation) => ScaleTransition(
    scale: animation,
    child: child,
  ),
  children: const [
    Text('Account'),
    Text('Preferences'),
    Text('Review'),
  ],
);

sequenceController.next();
sequenceController.previous();
sequenceController.goTo(2);
```

Navigation is immediate when its directional transition is omitted. Set
`keepMounted: true` only when inactive steps must preserve local widget state:
retained steps stay in memory and are still laid out offstage. With the default
`false`, only the current and transitioning steps are mounted.

During a transition, differently sized steps share the largest participant's
size and use `alignment`, which defaults to the directional top-start. A parent
such as `Center` can still move the whole `Sequence` as that outer size changes;
use stable parent constraints when the sequence needs a fixed external anchor.
For low-end devices, prefer paint or compositing transitions such as fade,
slide, and scale instead of builders that trigger layout on every frame.
Dispose an externally owned controller when its owner is disposed.

### Wait for route motion to settle

Use `RouteSettled` for controls or route chrome that should appear only after
the current route finishes moving and while no navigator gesture is active.
It has no built-in visual treatment: provide either direction's transition only
when the application needs one.

```dart
RouteSettled(
  showTransition: (child, animation) => FadeTransition(
    opacity: animation,
    child: child,
  ),
  child: const CloseButton(),
)
```

Showing takes 300 ms by default when a show transition exists. Hiding is
immediate by default. Without an enclosing route, the child is treated as
settled and shown.

### Represent offline Dio failures

Add `OfflineErrorDioInterceptor` when callers need to distinguish typed offline
failures from other Dio errors without scattering connectivity probes through
application code.

```dart
final dio = Dio()
  ..interceptors.add(OfflineErrorDioInterceptor());

try {
  await dio.get('/jobs');
} on DioException catch (error) {
  if (error.isOfflineConnectionDioException) {
    showOfflineState();
  }
}
```

The original error remains available as the cause of the typed offline
exception. Probe rules and timeout behavior are documented in the
[API reference][api].

### Launch phone calls and WhatsApp chats

Use `Telephony` and `Whatsapp` at the boundary where application data becomes
an external URI. Both utilities sanitize commonly formatted international
phone numbers and report whether the platform accepted the launch.

```dart
await Telephony().call(number: '+55 (11) 98888-7777');

await Whatsapp().launchChat(
  number: '+55 (11) 98888-7777',
  message: 'Hello! I would like more information.',
);
```

Always include the country code. These utilities sanitize URI input; they do
not verify that a phone number exists.

## Documentation

- Run the complete public-API [example][example].
- Read the generated [API reference][api] for contracts, defaults, exceptions,
  and focused examples.

## Scope

`oh_my_flutter` provides portable utility APIs. It intentionally does not own
application state, routing, localization, design components, or
application-specific domain logic.

[api]: https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/
[ci]: https://github.com/Ventairy/oh_my_flutter/actions/workflows/ci.yml
[ci-badge]: https://github.com/Ventairy/oh_my_flutter/actions/workflows/ci.yml/badge.svg
[example]: https://github.com/Ventairy/oh_my_flutter/blob/main/example/lib/main.dart
[license]: https://github.com/Ventairy/oh_my_flutter/blob/main/LICENSE
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[pub]: https://pub.dev/packages/oh_my_flutter
[pub-badge]: https://img.shields.io/pub/v/oh_my_flutter.svg
