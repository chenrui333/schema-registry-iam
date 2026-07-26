# Release Guide

## Version convention

Tags track `IMAGE_VERSION`: `v<IMAGE_VERSION>` (e.g. `v8.3.1`). Major and
minor versions track the compatible Confluent Platform line. Patch versions
identify releases of this image and may differ from the embedded Confluent
patch version; image `8.3.1`, for example, embeds Confluent `8.3.0`.

## Pre-release checklist

1. **Set `IMAGE_VERSION`** in `Dockerfile` to the new semantic version

   The release workflow rejects tags that do not exactly match this value.

2. **Sync `CP_VERSION` and `CP_DIGEST`** in `Dockerfile`

   The CI digest gate fails if they diverge.
   See `CLAUDE.md` for how to get the current digest.

3. **Sync `IAM_AUTH_VERSION` and `IAM_AUTH_JAR_SHA256`** in `Dockerfile`

   The build-time `sha256sum` check fails if they diverge.
   See `CLAUDE.md` for how to compute the correct JAR checksum.

4. **Run local validation**:
   ```bash
   just lint && just test
   ```

5. **Update `CHANGELOG.md`**: rename `## [Unreleased]` to `## [<IMAGE_VERSION>] - <YYYY-MM-DD>`,
   add a new empty `## [Unreleased]` section at the top, and update the comparison
   links footer at the bottom:
   ```text
   [Unreleased]: https://github.com/chenrui333/schema-registry-iam/compare/v<IMAGE_VERSION>...HEAD
   [<IMAGE_VERSION>]: https://github.com/chenrui333/schema-registry-iam/releases/tag/v<IMAGE_VERSION>
   ```

## Cut the release

Commit and push the `CHANGELOG.md` release-prep update to `main` before tagging.
The release tag should point at the commit that contains the final changelog entry.

```bash
git tag v<IMAGE_VERSION>
git push origin v<IMAGE_VERSION>
```

CI handles everything from here.

## Verify the release

1. Confirm the tag-triggered `Release` workflow succeeded for the exact tag.
2. Confirm the GitHub Release exists and is marked as the latest release.
3. Confirm GHCR contains `<IMAGE_VERSION>`, `<major>.<minor>`, `latest`, and
   the short commit SHA, all pointing to the released multi-architecture image.
4. Run `just validate ghcr.io/chenrui333/schema-registry-iam:<IMAGE_VERSION>`
   against the published image.

## What CI does automatically

On a `v*` tag push, `release.yml`:

1. Verifies the tag matches `IMAGE_VERSION`
2. Verifies `CP_DIGEST` matches the registry
3. Builds and validates `linux/amd64` and `linux/arm64` images
4. Pushes to GHCR with tags: `<IMAGE_VERSION>`, `<major>.<minor>`, `latest`, `<sha>`
5. Creates a GitHub Release with auto-generated notes prepended with GHCR pull commands

## Notes

- **Renovate PRs for `IAM_AUTH_VERSION` or `CP_VERSION`** require manual
  digest/checksum updates and a deliberate `IMAGE_VERSION` choice before
  release — automerge is intentionally disabled for these.
- **Immutable releases**: if repository-level immutable releases are enabled,
  GitHub Releases cannot be edited after creation.
- **Docs-only updates**: do not create another release tag for release-guide
  changes. Merging them still triggers the normal `main` publish workflow.
