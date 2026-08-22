# Release checklist

- Update `version` and `CHANGELOG.md`.
- Run `make check` and `make analyze-package` from a clean checkout.
- Inspect the publish archive for caches, overrides, agent files, and secrets.
- Confirm the tag is `v<pubspec version>` and points to protected `main`.
- Create the GitHub Release before enabling publishing automation for a new package.
- The first pub.dev release is manual; never publish from an unreviewed working tree.
- Configure pub.dev automated publishing for repository
  `Ventairy/oh_my_flutter` with tag pattern `v{{version}}`.
- Push the release tag and verify both the GitHub Actions workflow and the
  public pub.dev version reach a terminal successful state.
