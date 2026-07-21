# Release checklist

- Update `version` and `CHANGELOG.md`.
- Run `make check` and `make pana` from a clean checkout.
- Inspect the publish archive for caches, overrides, agent files, and secrets.
- Confirm the tag is `v<pubspec version>` and points to protected `main`.
- Create the GitHub Release before enabling publishing automation for a new package.
- The first pub.dev release is manual; never publish from an unreviewed working tree.
