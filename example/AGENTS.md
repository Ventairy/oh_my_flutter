# Example application guidance

## Purpose

The `example` application is a runnable gallery of `oh_my_flutter`'s public
APIs. Every gallery case must be visible and interactive where the API has an
interaction; do not leave examples as unused declarations.

Performance harnesses live under `benchmark/` and are separate from the
consumer-facing gallery.

## Gallery structure

- Keep `lib/main.dart` limited to app setup, section labels, and composition.
- Put each public feature case in `lib/examples/<feature>_example.dart`.
- Define one public `<Feature>Example` widget per file. A `StatefulWidget` and
  its private State class stay together.
- Keep each case self-contained. State, controllers, callbacks, and routes
  used only by that case belong in its example widget.
- Import only `package:oh_my_flutter/oh_my_flutter.dart`. Examples must never
  depend on package-private `lib/src` APIs.
- Prefer small examples that demonstrate one consumer outcome. Add a second
  file instead of turning one case into a broad gallery of unrelated APIs.
- Preserve compact-screen behavior: the composed gallery must remain
  scrollable without layout overflow.

## Tests

- Mirror every `lib/examples/<feature>_example.dart` owner with
  `test/examples/<feature>_example_test.dart`.
- Test the visible consumer behavior, including the primary interaction for
  stateful examples.
- Keep `test/utility_example_test.dart` as the composition smoke test for the
  complete gallery.
- Run tests from this directory with `fvm flutter test`.

## Validation

After changing the gallery:

1. Run `fvm dart format --output=none --set-exit-if-changed lib test`.
2. Run `fvm flutter analyze --fatal-infos`.
3. Run `fvm flutter test`.
4. From the package root, run `git diff --check`.

Use the repository's FVM-managed Flutter SDK. Do not invoke a global Flutter
installation or edit generated platform files for a Dart-only example change.

## Benchmarks

- Keep benchmark entrypoints and support code under `benchmark/<feature>/`.
- Do not import benchmark helpers into `lib/` or the interactive gallery.
- Preserve benchmark environment labels, validation records, and documented
  commands when editing an existing harness.
- Treat emulator results as relative stress evidence unless the documented
  renderer and hardware acceptance conditions are satisfied.
