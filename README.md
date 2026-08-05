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
  oh_my_flutter: ^0.5.0
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

### Add lightweight motion

Wrap any widget with `Motion` and an effect to add a reusable visual motion
treatment. `FloatingMotionEffect` creates a subtle, continuous vertical float
without changing the child's layout:

```dart
const Motion(
  effect: FloatingMotionEffect(
    delay: Duration(milliseconds: 300),
  ),
  child: Icon(Icons.cloud_outlined),
)
```

Use an effect's `delay` to wait before its playback. Customize the floating
distance, cycle duration, or timing curve on the effect. Effects own
configuration only; `Motion` owns the animation lifecycle and respects the
platform's reduced-motion preference.

Fade or scale a widget in, or move it between logical-pixel offsets with the
other built-in effects:

```dart
const Motion(
  effect: FadeInMotionEffect(),
  child: Text('Ready'),
)

const Motion(
  effect: ScaleInMotionEffect(scale: 0.6),
  child: Icon(Icons.check),
)

const Motion(
  effect: MoveMotionEffect(
    begin: Offset(-24, 0),
    end: Offset.zero,
  ),
  child: Icon(Icons.arrow_forward),
)
```

Use `onStart` and `onEnd` to react to each effect independently:

```dart
Motion(
  effect: FadeInMotionEffect(
    onStart: handleMotionStarted,
    onEnd: handleMotionCompleted,
  ),
  child: const Text('Ready'),
)
```

`onStart` runs after the effect's delay. `onEnd` runs when a one-shot effect
completes. Looping effects do not call `onEnd` while mounted, and canceled or
disposed effects are not reported as completed. Reduced-motion one-shot effects
call `onStart` followed immediately by `onEnd`.
`FloatingMotionEffect` exposes only `onStart` because it never completes.

Run effects concurrently or stagger them with independent delays:

```dart
const Motion.list(
  effects: [
    FadeInMotionEffect(),
    ScaleInMotionEffect(
      scale: 0.6,
      delay: Duration(milliseconds: 80),
    ),
  ],
  child: Text('Ready'),
)
```

The first effect is applied first, and each following effect composes around
the result. Keep the effects list immutable after passing it to `Motion.list`.
By default, pointer interaction is ignored while any effect is waiting or
playing. Set `interactive: true` to let the child receive taps during delays and
playback. Otherwise, interaction becomes available only after every one-shot
effect completes. A looping effect keeps interaction disabled while it remains
mounted.

Create a one-shot or looping effect by extending `MotionEffect`. The same effect works with `Motion` and `TextMotion`:

```dart
class SlideInMotionEffect extends MotionEffect {
  const SlideInMotionEffect()
    : super(duration: const Duration(milliseconds: 240));

  @override
  void apply(double progress, MotionEffectTransform transform) {
    transform.translate(x: 24 * (1 - progress), y: 0);
  }
}
```

One-shot effects run once per mounted `Motion`; assign a new key when an effect
should replay. Looping effects should render equivalent states at progress `0`
and `1` so their cycles remain seamless.

### Add motion to each text character

Use `TextMotion` with the same effects as `Motion` to animate every visible
Unicode grapheme in a plain Flutter `Text`. Whitespace and invisible formatting
controls remain static paragraph spans:

```dart
const TextMotion(
  effect: MoveMotionEffect(
    begin: Offset(0, 8),
    end: Offset.zero,
  ),
  stagger: Duration(milliseconds: 30),
  child: Text('Welcome'),
)
```

Combine effects with `TextMotion.list`:

```dart
const TextMotion.list(
  effects: [
    FadeInMotionEffect(),
    ScaleInMotionEffect(scale: 0.8),
  ],
  stagger: Duration(milliseconds: 30),
  child: Text('Ready'),
)
```

The default stagger is 30 milliseconds. One-shot effects finish after the
last character completes; looping effects retain their configured cycle
duration and use the stagger as a phase offset. Each effect keeps one shared
lifecycle, so `onStart` and `onEnd` fire once for the complete text rather than
once per character. Reduced motion, `TickerMode`, interaction, delays, and
playback otherwise match `Motion`.

Built-in and custom effects support the same opacity, translation, and scale
operations in both `Motion` and `TextMotion`.

`TextMotion` is intended for short display text. Rendering graphemes
independently necessarily changes cross-character typography such as kerning,
ligatures, contextual shaping, line wrapping, bidirectional layout, and
selection. It accepts `Text('...')`; `Text.rich` is not supported.

### Move widgets through a marquee

Use `Marquee` to move an ordered strip continuously through a clipped
viewport. The duration covers one complete pass of the source strip:

```dart
const Marquee(
  direction: MarqueeDirection.left,
  duration: Duration(seconds: 4),
  spacing: 24,
  infinity: true,
  children: [
    Text('Portable'),
    Text('Strongly typed'),
    Text('Low allocation'),
  ],
)
```

Horizontal marquees fill a bounded parent width by default and use their
tallest child for height. Vertical marquees fill a bounded parent height and
use their widest child. Supply `width` or `height` to request a fixed viewport
dimension. By default, `infinity: true` mounts only the minimum cyclic child
prefix needed to keep the viewport filled without a gap between loops. Set
`infinity: false` to mount each child once and use an offscreen-to-offscreen
pass instead. Child subtrees containing `GlobalKey`s are not supported while
infinity is enabled. Pointer interaction is disabled by default; set
`interactive: true` when moving children should accept taps. Reduced-motion
preferences leave the strip visible in a static arrangement.

### Pause child animations

Use `PauseAnimations` when a subtree's ticker callbacks should be muted. Its
default constructor accepts `paused`, which defaults to `true`:

```dart
PauseAnimations(
  paused: isLoading,
  child: const ProgressWidget(),
)
```

Use `PauseAnimations.temporarily` to enable callbacks automatically after a
fixed duration:

```dart
const PauseAnimations.temporarily(
  duration: Duration(milliseconds: 300),
  child: ProgressWidget(),
)
```

Flutter still advances elapsed ticker time while callbacks are muted, so child
animations catch up when they resume. A disabled ancestor `TickerMode` remains
in effect after `PauseAnimations` resumes its subtree.

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
For low-end devices, prefer lightweight transitions such as fade, slide, and
scale.
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
