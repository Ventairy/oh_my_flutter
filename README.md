# oh_my_flutter

[![CI][ci-badge]][ci]
[![License: MIT][license-badge]][license]
[![pub package][pub-badge]][pub]

Small, strongly typed utilities for common Flutter application tasks.

## Installation

> [!NOTE]
> Until the first pub.dev release, install the package from the immutable
> `v0.1.0` Git tag.

```yaml
dependencies:
  oh_my_flutter:
    git:
      url: https://github.com/Cataqui/oh_my_flutter.git
      ref: v0.1.0
```

After publication, install the latest compatible release with:

```console
flutter pub add oh_my_flutter
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
[ci]: https://github.com/Cataqui/oh_my_flutter/actions/workflows/ci.yml
[ci-badge]: https://github.com/Cataqui/oh_my_flutter/actions/workflows/ci.yml/badge.svg
[example]: https://github.com/Cataqui/oh_my_flutter/blob/main/example/lib/main.dart
[license]: https://github.com/Cataqui/oh_my_flutter/blob/main/LICENSE
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[pub]: https://pub.dev/packages/oh_my_flutter
[pub-badge]: https://img.shields.io/pub/v/oh_my_flutter.svg
