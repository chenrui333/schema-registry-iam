# Release Guide

## Version convention

Tags track `CP_VERSION`: `v<CP_VERSION>` (e.g. `v8.2.0`).

## Pre-release checklist

1. **Sync `CP_VERSION` and `CP_DIGEST`** in `Dockerfile`

   The CI digest gate fails if they diverge.
   See `CLAUDE.md` for how to get the current digest.

2. **Sync `IAM_AUTH_VERSION` and `IAM_AUTH_JAR_SHA256`** in `Dockerfile`

   The build-time `sha256sum` check fails if they diverge.
   See `CLAUDE.md` for how to compute the correct JAR checksum.

3. **Run local validation**:
   ```bash
   just lint && just test
   ```

4. **Update `CHANGELOG.md`**: rename `## [Unreleased]` to `## [<CP_VERSION>] - <YYYY-MM-DD>`,
   add a new empty `## [Unreleased]` section at the top, and update the comparison
   links footer at the bottom:
   ```text
   [Unreleased]: https://github.com/chenrui333/schema-registry-iam/compare/v<CP_VERSION>...HEAD
   [<CP_VERSION>]: https://github.com/chenrui333/schema-registry-iam/releases/tag/v<CP_VERSION>
   ```

## Cut the release

```bash
git tag v<CP_VERSION>
git push origin v<CP_VERSION>
```

CI handles everything from here.

## What CI does automatically

On a `v*` tag push, `release.yml`:

1. Verifies `CP_DIGEST` matches the registry
2. Builds and validates `linux/amd64` and `linux/arm64` images
3. Pushes to GHCR with tags: `<CP_VERSION>`, `<major>.<minor>`, `latest`, `<sha>`
4. Creates a GitHub Release with auto-generated notes prepended with GHCR pull commands

## Notes

- **Renovate PRs for `IAM_AUTH_VERSION` or `CP_VERSION`** require manual digest/checksum
  updates before merging — automerge is intentionally disabled for these.
- **Immutable releases**: if repository-level immutable releases are enabled,
  GitHub Releases cannot be edited after creation.
