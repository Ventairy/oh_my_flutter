## Unreleased

- Add `InteractiveSwipeDismiss` for translating any live content with a
  configurable, scroll-aware directional dismissal gesture, callback-owned
  removal, and presentation-neutral drag-handle regions.
- **Breaking:** Replace `MorphForeground` with tagged `MorphSibling` controls
  that coordinate widgets outside a Morph subtree through matching visual
  progress and configurable above-Morph paint ordering.
- Keep watched Morph destination snapshots aligned with geometry and content
  changes during active forward and reverse flights while reusing unchanged
  images whenever changes are directly observable.
- Add `Device` for grouping device features and `DeviceDisplay` for reading
  exact display corner radii with an optional approximate phone fallback.

## 0.15.0

- Add device-formatted current addresses with selectable nullable components,
  retained coordinates, an optional best-effort locale, and a bounded
  reverse-geocoding wait, while keeping `DeviceLocation` implementable for
  consumer test doubles.

## 0.14.0

- **Breaking:** Make `Skeleton` represent the first visibly painted descendant
  on each branch as one bone, and add nested `SkeletonDescendant` behaviors for
  painting a branch root, deferring to its children, or hiding it while
  retaining layout.

## 0.13.0

- **Breaking:** Rename `ControlledVisibilityController` to
  `VisibilityController`.
- Add a generic callable `Debouncer<T>` for delaying repeated synchronous or
  asynchronous callbacks, sharing the latest pending result, discarding
  superseded running results by default, and explicitly cancelling or disposing
  active results.

## 0.12.0

- Add `Skeleton` for turning existing widget layouts into neutral loading
  placeholders with optional fade and shimmer effects, configurable rectangular
  radius and effect timing, and a localized live loading-status label.
- Keep multiline `Morph` text fully visible and following `Column` content
  correctly positioned and spaced while typography grows or shrinks, with
  children corresponding by position regardless of their Flutter keys.
- Prevent shrinking reverse `Morph` transitions from leaving duplicated text
  from earlier frames.

## 0.11.1

- Add `DeviceLocation` for managing foreground permission and settings and
  retrieving fresh Android or iOS coordinates. This release requires Flutter
  3.47 and Dart 3.13.

## 0.11.0

- This version was tagged but not published.

## 0.10.0

- Preserve visual continuity when `Morph` transitions overlap or hand their
  completed flight to a live endpoint, including route reversals and retargets.
- Add configurable live or preserved `MaybeSafeArea` positioning so controls
  can either track unsafe edges while moving or retain their initial correction
  within a moving surface.

## 0.9.0

- Add `MorphForeground` for keeping live controls and other content visible
  above nearby Morph transitions without joining their animation.

## 0.8.2

- Keep `RouteSettled` content hidden while another route covers it, then replay
  its configured show behavior after that route fully leaves.

## 0.8.1

- Make the repository's consumer guides easier to discover from the README,
  alongside the generated API reference and runnable example.

## 0.8.0

- Add `MaybeSafeArea` to keep a child's layout bounds out of enabled unsafe view
  edges as it moves or scrolls, without changing layout or delaying its first
  rendered frame.

## 0.7.1

- Fix nested Morphs without a matching endpoint in the current transition so
  they remain visible as ordinary content inside their ancestor's flight.

## 0.7.0

- **Breaking:** Extend automatic Morph transitions with `MorphDescendant`
  configuration for how selected subtrees participate in their nearest Morph,
  including live, snapshotted, or hidden flight behavior; optional transitions
  for discrete content switches; destination tracking configured by the
  departing Morph; and specialized transitions through eligible `Motion`
  wrappers.
  Rename `Morph.watch` to `watchDestination` and
  `nonMorphDescendantsTransition` to `switchTransition`.

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
