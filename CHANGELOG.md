## 0.6.1

- Add `Morph` shared-element transitions for any widget across routes or within
  the same screen. Eligible `Text`, `Container`, `DecoratedBox`, and vertical
  `Column` pairs receive specialized transitions automatically, while other
  pairs use the generic content switch. Nested Morphs inherit an omitted
  duration or curve from their nearest Morph ancestor. Custom typed flight
  delegates remain available when needed.
- Reorganize package documentation into focused consumer guides for widgets,
  extensions, networking, and utilities, with a compact README catalog that
  links to each documentation section.
- Add configurable `MotionStartup` behavior and `MotionController` playback for
  `Motion` and `TextMotion`, including automatic playback, a held starting
  state, or a skipped ending state with controller-driven playback on demand.
- Add `ShakeMotionEffect` for damped horizontal, vertical, or diagonal shakes
  with configurable strength, excursion count, timing, and playback.
- Add `MotionEffectBounds` for declaring translation and scale ranges for
  custom effects with oscillating, abrupt, or short-lived visual extremes.

## 0.5.0

- **Breaking:** Replace `MotionEffect.buildTransition` with
  `MotionEffect.apply`. Custom effects now use `MotionEffectTransform` to
  compose opacity, translation, and uniform scale. The same custom effect can
  be used by both `Motion` and `TextMotion`.
- Add `TextMotion` and `TextMotion.list` for applying existing motion effects
  to the visible Unicode graphemes in plain Flutter text, with configurable
  staggering and effect lifecycle callbacks for the complete text.
- Add `Marquee` for continuously moving an ordered widget strip in any
  physical direction, with bounded or explicit viewport sizing, configurable
  loop duration and spacing, continuous repetition through `infinity`,
  reduced-motion handling, and opt-in interaction.

## 0.4.1

- Add effect-level `onStart` and `onEnd` lifecycle callbacks to `MotionEffect`,
  with `onStart` on every built-in effect and `onEnd` on one-shot effects.
- Keep `Motion` interaction disabled during effect delays when `interactive`
  is false.
- Add `MotionPlayback.isOnce` for semantic playback branching.

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
