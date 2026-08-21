# AGENTS.md — oh_my_flutter

## Mission

`oh_my_flutter` is a public, general-purpose Flutter utility package. Keep it
small, portable, strongly typed, and useful outside Cataquí applications.

## Environment and commands

- Use Flutter 3.44.0 through FVM. Never invoke an untracked global Flutter SDK.
- Do not commit the root `pubspec.lock`; resolve the package's newest compatible
  dependencies during normal development and CI. Commit `example/pubspec.lock`
  and enforce it for the runnable example application.
- Use the root Makefile; this repository does not use Melos.
- Keep the Makefile as a local developer interface. GitHub Actions workflows
  must run the underlying FVM commands directly instead of invoking Make targets.
- Run `make check` before every pull request and `make pana` for publication changes.

## Public API

- Export consumer APIs explicitly from `lib/oh_my_flutter.dart`.
- Design every API and behavior for reuse across unrelated applications. Do not
  encode one app's business logic, styling, motion preferences, layout choices,
  content assumptions, or other product-specific decisions in this package.
  Expose product choices as explicit consumer configuration instead.
- Add a default only when it represents neutral, broadly applicable behavior;
  never choose one merely because it suits the current consumer. Configurable
  animation curves default to `Curves.linear`; consumers must explicitly opt
  into eased, branded, or otherwise opinionated motion.
- Every exported declaration and public member requires useful Dartdoc.
- Lead public Dartdoc with the concrete outcome the API helps consumers
  achieve. Explain its purpose through familiar use cases before adding
  behavior details, configuration, or constraints; avoid abstract summaries
  when a direct description would be easier to understand.
- When a dedicated consumer guide under `doc/` provides useful detail for a
  public API, link to it from the owning declaration's Dartdoc. Use the guide's
  canonical GitHub URL so the link also works in generated API documentation.
- Keep Dartdoc for extensible containers, such as libraries, classes,
  extensions, and mixins, generic enough to remain accurate when new
  capabilities are added. Do not define a container solely by the first or
  only feature it currently exposes; document feature-specific behavior on the
  member that provides it.
- Write Dartdoc exclusively from the consumer's perspective: explain how to use
  the API, what it visibly or observably does, and any constraints the consumer
  must act on. Do not mention internal structure, coordination, or mechanics
  merely because they are technically accurate. Include a technical constraint
  only when it changes consumer usage or an observable result, and describe its
  consumer-facing consequence rather than how the implementation works.
- Keep public Dartdoc and README content focused on consumer-facing behavior,
  usage, and outcomes. Do not explain internal implementation or optimization
  machinery such as render objects, scheduler entries, shared frame callbacks,
  transform accumulators, allocation strategies, paint-bound sampling, caches,
  or batching. Consumers should only need to know that an API is optimized,
  not how that optimization is implemented.
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
- Keep each enum in its own file with no other declarations. Name the file
  after the enum in snake case, such as `MotionPlayback` in
  `motion_playback.dart`.
- Do not declare typedefs or callback aliases used in only one place. Write the
  function type inline at the callback definition. When an alias is reused,
  declare it in a `*_types.dart` file that is part of the owning library.
- Extensions belong under `lib/src/extensions`; keep one canonical extension per target type.
- Network behavior belongs under `lib/src/dio_interceptors` and domain-specific
  failures under `lib/src/exceptions`.
- Prefer explicit, readable code, immutable values, named parameters for
  multi-argument APIs, early returns, and exhaustive enum switches.
- Prefer semantic enum methods and getters over raw equality comparisons when
  an enum exposes or can provide them. For example, use `status.isCompleted`
  and `playback.isOnce` instead of comparing directly with enum values.
- Do not add top-level helpers. Public top-level builder factories are not
  needed in this package.
- Optimize utilities used during scrolling or gestures for low-end devices:
  avoid repeated allocation, avoid blocking work, and keep hot paths synchronous.
- Treat invalid developer-supplied configuration as a contract violation, in
  line with Flutter APIs: diagnose it with `assert` rather than deliberately
  throwing `ArgumentError` or another runtime exception in release builds.
  Validate runtime/user input normally when failure is an expected use case.
- Put const-evaluable contract assertions directly in const constructors. When
  Dart does not allow a required expression in a const constructor assertion,
  place that check in a debug validator that returns `true` and invoke the
  validator only from an `assert`; never call a debug validator unconditionally.
  Invalid configurations remain unsupported when assertions are disabled.

## Tests and debugging

- Every source owner has a mirrored dedicated test file.
- Every bug fix includes a regression test, test-first when the cause is known.
- Test names use `when ..., it should ...`; keep one assertion per test case.
- Pin time with `package:clock` whenever behavior depends on the current time.
- Diagnose and reproduce uncertain failures before changing production code.
- Fix analyzer findings in source; do not add blanket ignores or change `.agents` copies to satisfy Dart analysis.
- Use `goldenTest` from `alchemist`, not raw `matchesGoldenFile` assertions.
- Keep golden tests beside their widget tests and commit their CI references
  under `test/**/goldens/ci/`.
- Keep platform references under `test/**/goldens/macos/`,
  `test/**/goldens/linux/`, or `test/**/goldens/windows/`; these references stay
  local and are ignored by Git and package publishing.
- Regenerate approved references from the repository root with
  `make update-goldens`, then inspect every changed image before accepting it.

## Documentation and releases

- Give every independently usable exported feature a dedicated consumer guide
  in the matching category folder under `doc/`, using a snake_case filename.
  Keep detailed usage, configuration, examples, and constraints in that guide.
- Treat the README as the authoritative public feature catalog because pub.dev
  presents it to consumers. Keep each entry brief and link once from each
  category heading to its documentation folder; do not maintain per-feature
  guide links or duplicate the feature inventory in another index.
- List a feature anywhere else only when that list is necessary for the reader's
  task, not merely as navigation or a second catalog that must stay synchronized.
- Keep feature guides limited to public imports and consumer-observable
  behavior. Update a guide when its documented usage, configuration, or
  actionable constraints change. Follow the additional local rules in
  `doc/AGENTS.md`.
- Update only the public artifacts whose audience needs the change. Do not
  mechanically update README, API docs, guides, or examples for every
  user-visible code change.
- Do not document expected behavior merely because a bug exposed or clarified
  it. A bug fix that restores behavior already implied by the API normally
  needs a regression test and a consumer-facing CHANGELOG entry, but no README,
  guide, Dartdoc, or example change. Update those surfaces only when consumers
  must discover a new capability, change how they use the API, choose between
  meaningful options, or act on a non-obvious constraint.
- While a feature remains unreleased, maintain one concise, consumer-facing
  CHANGELOG entry that describes its overall capability. As development
  iterates and its scope grows, revise that entry instead of adding separate
  entries for each constituent behavior, implementation detail, optimization,
  bug fix, or refinement. Use more granular entries only for changes made after
  the feature has appeared in a public release.
- Keep the example runnable and limited to public imports.
- Verify `make check`, `make pana`, and an inspected zero-warning publish dry run.
- Never run a real `pub publish` command without explicit release authorization.
- Release tags are immutable and must match `pubspec.yaml` (`v0.1.0` for version `0.1.0`).
