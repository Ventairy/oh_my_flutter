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
  oh_my_flutter: ^0.13.0
```

Import the public library wherever you need it:

```dart
import 'package:oh_my_flutter/oh_my_flutter.dart';
```

## Documentation

- Read the repository [consumer guides][guides] for setup, usage, configuration,
  and constraints.
- Read the generated [API reference][api] for exhaustive contracts and defaults.
- Run the complete public-API [example][example].

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

## [Extensions][extension-guides]

### DateTime relative time

`DateTime.timeAgo` maps elapsed time to application-owned callbacks, so callers
control localization and the result type.

### Color transformations

`ColorExtension` lightens, darkens, converts Flutter colors to hexadecimal, and
starts OKLCH conversion.

### OKLCH colors

`Oklch` provides perceptually uniform lightness, chroma, and hue values with
conversion to and from Flutter colors.

### Velocity classification

`VelocityExtension` classifies directional swipe velocity while leaving
distance, progress, and interaction policy to the application.

## [Widgets][widget-guides]

### ControlledVisibility

`ControlledVisibility` lets parent-owned state show or hide a child with
optional directional transitions and optional unmounting.

### Morph

`Morph` animates matching widgets between layouts and routes, selecting a
specialized transition for supported content and a generic transition for
other widgets. `MorphDescendant` configures how a selected descendant subtree
participates in its nearest ancestor Morph, currently including live,
snapshotted, or hidden transition behavior. Discrete content switches and
moving destinations remain configurable without replacing the automatic
transition. `MorphForeground` keeps live controls visible above those flights
without animating them as matched content.

### Motion

`Motion` applies reusable one-shot or looping effects, including shakes, to any
widget with configurable startup and controller-driven playback.

### TextMotion

`TextMotion` applies the same motion effects to each visible grapheme in short
display text with configurable startup and controller-driven playback.

### Marquee

`Marquee` repeatedly moves an ordered strip through a clipped viewport, with
gapless or single-strip cycle layouts.

### PauseAnimations

`PauseAnimations` temporarily mutes ticker callbacks for a widget subtree.

### MaybeSafeArea

`MaybeSafeArea` keeps a child's layout bounds out of enabled unsafe view edges
as it moves or scrolls, without changing its layout footprint.

### Sequence

`Sequence` presents one child at a time with controller-owned navigation and
optional directional transitions.

### RouteSettled

`RouteSettled` shows route chrome or controls only while the enclosing route is
settled and no navigator gesture is active.

### Skeleton

`Skeleton` preserves a widget subtree's layout while replacing the first
painted descendant on each branch with neutral loading bones, with optional
descendant overrides and fade or shimmer effects.

## [Networking][networking-guides]

### Offline Dio errors

`OfflineErrorDioInterceptor` turns conservatively classified offline Dio
failures into a typed error that callers can detect without repeating
connectivity probes.

## [Utilities][utility-guides]

### Debouncer

`Debouncer<T>` delays repeated value-producing callbacks until calls stop,
while sharing the latest callback's result across the pending burst.

### Device location

`DeviceLocation` manages foreground location permission and retrieves fresh
coordinates or a device-formatted current address on Android or iOS.

### Telephony

`Telephony` sanitizes an international phone number and asks the platform to
start a call.

### WhatsApp

`Whatsapp` opens a chat with an optional message through the native application
or web fallback.

## Scope

`oh_my_flutter` provides portable utility APIs. It intentionally does not own
application state, routing, localization, design components, or
application-specific domain logic.

[api]: https://pub.dev/documentation/oh_my_flutter/latest/oh_my_flutter/
[ci]: https://github.com/Ventairy/oh_my_flutter/actions/workflows/ci.yml
[ci-badge]: https://github.com/Ventairy/oh_my_flutter/actions/workflows/ci.yml/badge.svg
[example]: https://github.com/Ventairy/oh_my_flutter/blob/main/example/lib/main.dart
[extension-guides]: https://github.com/Ventairy/oh_my_flutter/tree/main/doc/extensions
[guides]: https://github.com/Ventairy/oh_my_flutter/tree/main/doc
[license]: https://github.com/Ventairy/oh_my_flutter/blob/main/LICENSE
[license-badge]: https://img.shields.io/badge/license-MIT-blue.svg
[networking-guides]: https://github.com/Ventairy/oh_my_flutter/tree/main/doc/networking
[pub]: https://pub.dev/packages/oh_my_flutter
[pub-badge]: https://img.shields.io/pub/v/oh_my_flutter.svg
[utility-guides]: https://github.com/Ventairy/oh_my_flutter/tree/main/doc/utilities
[widget-guides]: https://github.com/Ventairy/oh_my_flutter/tree/main/doc/widgets
