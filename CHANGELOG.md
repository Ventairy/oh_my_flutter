## 0.4.0

- Add extensible single- and multi-effect `Motion` composition with one-shot
  and looping playback, including independent per-effect startup delays, the
  built-in `FadeInMotionEffect`,
  `ScaleInMotionEffect`, paint-only `MoveMotionEffect` and
  `FloatingMotionEffect`, reduced-motion handling, a shared frame scheduler,
  optional interaction blocking during playback and render-layer transforms.
- Add `PauseAnimations` for muting subtree ticker callbacks either explicitly
  or for a fixed duration.
- Add controller-driven `Sequence` for displaying ordered widgets one at a
  time, with indexed navigation, optional directional transitions, and
  configurable child-state retention. Its lazy entry lifecycle limits mounted
  and animated work to participating children by default, while configurable
  alignment anchors differently sized transition participants.

## 0.3.2

- Remove the root package lockfile from version control.

## 0.3.1

- Align the package's explicit formatter settings with `pana` so local and
  publication analysis both pass at the configured 120-column width.

## 0.3.0

- Add controller-driven `ControlledVisibility` with independent caller-owned
  show and hide transitions, configurable timing, reduced-motion handling, and
  mounted or unmounted hidden-state behavior.
- Add `RouteSettled` for showing route content only after navigation motion and
  user gestures finish, with optional direction-specific transitions.
- Improve pubspec description.

## 0.2.0

- **Breaking:** Remove `StringExtension.hexToColor()`. Use Flutter `Color`
  constructors or an application-owned parser for string input.
- Improve the README, example, and public API documentation.
- Add trusted pub.dev publishing through GitHub Actions.
- Use the canonical Ventairy repository links in package metadata.

## 0.1.0

- Initial public release.
- Add deterministic relative-time formatting with configurable fallback
  behavior.
- Add color, OKLCH, string, object, and gesture velocity extensions.
- Add offline Dio interception and a typed offline connection exception.
- Add portable telephony and WhatsApp URI helpers.
