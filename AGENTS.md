# AGENTS.md — oh_my_flutter

## Mission

`oh_my_flutter` is a public, general-purpose Flutter utility package. Keep it
small, portable, strongly typed, and useful outside Cataquí applications.

## Environment and commands

- Use Flutter 3.44.0 through FVM. Never invoke an untracked global Flutter SDK.
- Use the committed `pubspec.lock` for deterministic development and CI.
- Use the root Makefile; this repository does not use Melos.
- Run `make check` before every pull request and `make pana` for publication changes.

## Public API

- Export consumer APIs explicitly from `lib/oh_my_flutter.dart`.
- Every exported declaration and public member requires useful Dartdoc.
- Keep Dartdoc for extensible containers, such as libraries, classes,
  extensions, and mixins, generic enough to remain accurate when new
  capabilities are added. Do not define a container solely by the first or
  only feature it currently exposes; document feature-specific behavior on the
  member that provides it.
- Avoid `dynamic`; narrow unknown values at their boundary.
- Preserve backwards compatibility within a minor release. Document breaking
  changes and release them with the appropriate semantic version.
- Prefer SDK capabilities over new dependencies. Explain every added runtime dependency.
- Keep package code free of Cataquí-specific services, URLs, models, tokens, and assumptions.

## Architecture and code

- Keep one class per file, except for a `StatefulWidget` and its `State` class.
  Keep those two classes together in the widget's file for easier reading; do
  not split the state class into a `part of` file. Other additional classes in
  the same library must live in separate `part of` files.
- Place libraries that use `part` or `part of`, and other closely related
  source files, in a dedicated folder. Keep the owning library and its related
  files together in that folder.
- Do not declare typedefs or callback aliases used in only one place. Write the
  function type inline at the callback definition. When an alias is reused,
  declare it in a `*_types.dart` file that is part of the owning library.
- Extensions belong under `lib/src/extensions`; keep one canonical extension per target type.
- Network behavior belongs under `lib/src/dio_interceptors` and domain-specific
  failures under `lib/src/exceptions`.
- Prefer explicit, readable code, immutable values, named parameters for
  multi-argument APIs, early returns, and exhaustive enum switches.
- Do not add top-level helpers. Public top-level builder factories are not
  needed in this package.
- Optimize utilities used during scrolling or gestures for low-end devices:
  avoid repeated allocation, avoid blocking work, and keep hot paths synchronous.

## Tests and debugging

- Every source owner has a mirrored dedicated test file.
- Every bug fix includes a regression test, test-first when the cause is known.
- Test names use `when ..., it should ...`; keep one assertion per test case.
- Pin time with `package:clock` whenever behavior depends on the current time.
- Diagnose and reproduce uncertain failures before changing production code.
- Fix analyzer findings in source; do not add blanket ignores or change `.agents` copies to satisfy Dart analysis.

## Documentation and releases

- Update README, API docs, example, and CHANGELOG for user-visible changes.
- Keep the example runnable and limited to public imports.
- Verify `make check`, `make pana`, and an inspected zero-warning publish dry run.
- Never run a real `pub publish` command without explicit release authorization.
- Release tags are immutable and must match `pubspec.yaml` (`v0.1.0` for version `0.1.0`).
