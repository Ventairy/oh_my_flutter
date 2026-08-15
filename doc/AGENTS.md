# AGENTS.md — package guides

## Scope

This directory owns consumer guides for every public package feature. Keep the
root README as a compact catalog that links here.

## Structure

- Put widget guides in `widgets/`.
- Put extension guides in `extensions/`.
- Put network behavior in `networking/`.
- Put other service and utility classes in `utilities/`.
- Give each independently usable public feature its own snake_case Markdown
  file. Group declarations only when consumers use them as one feature, such as
  the offline interceptor, exception, and detection extension.
- Keep the root README as the only complete feature inventory. Link each README
  category heading to its folder instead of maintaining per-feature guide links.
- Do not create another guide index or feature catalog under `doc/`. List
  individual guides elsewhere only when the consumer's task requires it.

## Content

- Write exclusively from the consumer's perspective: purpose, setup, visible or
  observable behavior, configuration, constraints, and focused examples.
- Use only exports from `package:oh_my_flutter/oh_my_flutter.dart` in examples.
- Keep implementation and optimization machinery out of guides.
- Put detailed usage here, not in the root README. Do not duplicate long
  examples or reference material between both locations.
- Link to the generated API reference for exhaustive member contracts rather
  than reproducing every parameter.
- Update a guide whenever its feature's public behavior changes. New public
  features are incomplete until their guide and index entry exist.

## Validation

- Check every relative Markdown link after moving or adding a guide.
- Keep code fences balanced and examples formatted as valid Dart snippets.
- Run the repository documentation and publication checks required by the root
  `AGENTS.md` before release.
