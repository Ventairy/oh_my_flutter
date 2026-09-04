# oh_my_flutter

[![CI][ci-badge]][ci]
[![License: MIT][license-badge]][license]
[![pub package][pub-badge]][pub]

Reusable Flutter tools for animations, gestures, loading states, device
features, networking, and other common application tasks.

## Installation

Add the latest compatible release from pub.dev:

```console
flutter pub add oh_my_flutter
```

Or add it directly to your `pubspec.yaml`:

```yaml
dependencies:
  oh_my_flutter: ^0.19.0
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

This example starts with an accent color, makes it lighter, produces a hex
color value, and converts it to the OKLCH color model:

```dart
import 'package:flutter/material.dart';
import 'package:oh_my_flutter/oh_my_flutter.dart';

final accent = const Color(0xFFFF4A4B);
final lighterAccent = accent.lighten(0.12);
final hex = lighterAccent.toHex();
final oklch = lighterAccent.toOklch();
```

## Extensions

See the [extension guides][extension-guides] for usage examples, available
options, and constraints.

### DateTime relative time

`DateTime.timeAgo` turns a date and time into a relative value such as “now” or
“5 minutes ago.” The application supplies the wording, so it can localize the
result for its users.

### Color transformations

`ColorExtension` adds convenient operations to Flutter colors. It can make a
color lighter or darker, produce a hexadecimal color value, and begin an OKLCH
conversion.

### Double validation

`DoubleExtension` adds convenient operations to Flutter doubles.

### OKLCH colors

OKLCH is a color model designed to make visual color adjustments more
predictable. `Oklch` describes a color by its perceived lightness, intensity,
and hue, and converts between OKLCH and Flutter colors.

### Velocity classification

`VelocityExtension` detects whether a completed drag was a fast swipe and
identifies its direction. Applications can use that result to decide whether
to dismiss, navigate, or complete another gesture.

## Widgets

See the [widget guides][widget-guides] for usage examples, available options,
and constraints.

### ControlledVisibility

`ControlledVisibility` shows or hides a user-interface element on command. The
change can happen immediately or with an animation, and hidden content can
either stay loaded or be removed.

### InteractiveSwipeDismiss

`InteractiveSwipeDismiss` lets a user drag a widget, such as a page or card,
away to dismiss it. The application decides whether to accept the dismissal or
restore the widget, and can choose the drag direction and active handle area.

### Morph

A morphing transition makes the same visual appear to move and reshape smoothly
between two positions, layouts, or screens.

#### Morph

`Morph` creates that transition between matching widgets. It automatically
adapts supported content and can also animate other widgets, content changes,
and destinations that continue moving during the transition.

#### MorphDescendant

`MorphDescendant` controls how one selected part inside a `Morph` participates
in the transition. That part can remain live, appear as a captured image, or
stay hidden while the transition runs.

#### MorphSibling

`MorphSibling` lets a separate widget outside a `Morph` follow the same
transition. It can move in sync while remaining in its normal visual layer or
appearing above the transition.

### Motion

`Motion` adds reusable visual effects, such as fading, scaling, moving, floating, shaking, etc. to any widget. Effects can run once, repeat, start automatically,
or be controlled by the application.

### TextMotion

`TextMotion` animates each visible character in a short piece of text. It uses
the same effects as `Motion` and can stagger them so neighboring characters
start at different times.

### Marquee

A marquee is a continuously scrolling row of content shown through a limited
visible area. `Marquee` moves an ordered set of widgets in a chosen direction
and can repeat it as one strip or as a gapless loop.

### PauseAnimations

`PauseAnimations` temporarily pauses animations in one section of the user
interface. It is useful when that content is hidden, inactive, or should wait
before it starts moving.

### MaybeSafeArea

`MaybeSafeArea` keeps moving, floating, or scrolling content away from unsafe
screen edges, such as notches, rounded corners, and system interface areas. It
adds protection only when the content reaches an enabled edge.

### NativeSelectableText

`NativeSelectableText` keeps text rendering and selection in Flutter while
showing native selection menus on Android, iOS, macOS, Windows, and Linux, with
an adaptive Flutter fallback elsewhere.

### Sequence

`Sequence` presents one step at a time in an ordered flow, such as onboarding
or a multi-step form. The application can move forward, backward, or directly
to a step, with optional transition animations.

### RouteSettled

`RouteSettled` shows controls only when the current screen has finished entering
and is not being covered or moved by navigation. This can keep buttons and
headers out of view during page transitions or back-swipe gestures.

### Skeleton

A skeleton is a temporary loading placeholder that shows the shape of the
expected interface while real content is still loading. `Skeleton` creates
those neutral shapes from an existing widget layout and can display them as a
static placeholder or with fade and shimmer effects.

## Networking

See the [networking guides][networking-guides] for setup instructions, usage
examples, and failure behavior.

### Offline Dio errors

`OfflineErrorDioInterceptor` helps applications distinguish a likely loss of
internet access from other HTTP request failures produced by Dio. Callers can
detect the resulting offline error and show an appropriate message or recovery
action.

## Utilities

See the [utility guides][utility-guides] for usage examples, platform behavior,
and configuration.

### Device

`Device` provides one place to access several device-related features. Use it
when the same part of an application needs both display and location tools.

#### Display

`DeviceDisplay` reads information about the physical screen. It can report the
screen's rounded-corner sizes so an interface can align with or avoid them, and
returns null when Flutter or the current mobile platform cannot provide
trustworthy values.

#### Location

`DeviceLocation` requests permission to use the device's location while the app
is open. It can then retrieve current coordinates or a formatted address on
Android and iOS.

### Debouncer

A debouncer waits for rapid repeated actions to stop before running work. For
example, `Debouncer<T>` can wait until a user pauses typing before requesting
search suggestions, ensuring the latest request supplies the pending result.

### Telephony

`Telephony` cleans the formatting from an international phone number and asks
the operating system to open its phone interface for that number.

### WhatsApp

`Whatsapp` opens a chat for a phone number with an optional pre-filled message.
It tries the native WhatsApp application when available and otherwise uses the
web version.

## Scope

`oh_my_flutter` supplies reusable building blocks rather than a complete
application framework. The application remains responsible for its state,
navigation, translated text, visual design, and business rules.

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
