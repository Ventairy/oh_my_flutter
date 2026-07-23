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
