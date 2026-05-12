# Changelog

All notable changes to this project are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
Versioning: [Semantic Versioning](https://semver.org/) — version tracks `CP_VERSION`.

## [Unreleased]

### Added

- CI: CP_DIGEST consistency gate in `publish.yml` and `release.yml` — fails fast with the correct digest if the Dockerfile is stale ([#14](https://github.com/chenrui333/schema-registry-iam/pull/14))
- CI: Concurrency group in `publish.yml` — stale PR runs cancelled; main-branch runs queue so every commit gets its SHA tag ([#14](https://github.com/chenrui333/schema-registry-iam/pull/14))
- Dev: `just lint` recipe running `shellcheck` and `hadolint` ([#14](https://github.com/chenrui333/schema-registry-iam/pull/14))
- Dev: Pin `shellcheck 0.11.0` and `hadolint 2.14.0` in `mise.toml` ([#14](https://github.com/chenrui333/schema-registry-iam/pull/14))
- Renovate: Track `CP_VERSION` automatically via Docker Hub datasource ([#14](https://github.com/chenrui333/schema-registry-iam/pull/14))
- Docs: Workflow status badges in README ([194b878](https://github.com/chenrui333/schema-registry-iam/commit/194b878))
- CI: Tag release workflow with automated GitHub Release notes ([5495b10](https://github.com/chenrui333/schema-registry-iam/commit/5495b10))

### Changed

- Bump `confluentinc/cp-schema-registry` base image from `7.9.6` to `8.2.0` ([#6](https://github.com/chenrui333/schema-registry-iam/pull/6))
- Bump `actions/checkout` from v4 to v6 ([#3](https://github.com/chenrui333/schema-registry-iam/pull/3))
- Bump `docker/build-push-action` from v6 to v7 ([#7](https://github.com/chenrui333/schema-registry-iam/pull/7))
- Bump `docker/login-action` from v3 to v4 ([#8](https://github.com/chenrui333/schema-registry-iam/pull/8))
- Bump `docker/metadata-action` from v5 to v6 ([#9](https://github.com/chenrui333/schema-registry-iam/pull/9))
- Bump `docker/setup-buildx-action` from v3 to v4 ([#10](https://github.com/chenrui333/schema-registry-iam/pull/10))
- Bump `docker/setup-qemu-action` from v3 to v4 ([#11](https://github.com/chenrui333/schema-registry-iam/pull/11))
- Bump `just` from `1.48.0` to `1.50.0` ([#2](https://github.com/chenrui333/schema-registry-iam/pull/2), [#12](https://github.com/chenrui333/schema-registry-iam/pull/12))
- Migrate Renovate config to `config:best-practices` with `platformAutomerge` and 7-day cooldown ([#1](https://github.com/chenrui333/schema-registry-iam/pull/1), [#4](https://github.com/chenrui333/schema-registry-iam/pull/4))

### Fixed

- Renovate automerge disabled for `custom.regex`-managed deps — prevents permanently-failing automerge PRs for deps that require a manual SHA/digest update ([#14](https://github.com/chenrui333/schema-registry-iam/pull/14))
- `scripts/test-image.sh`: JAR-absent check no longer exits the script prematurely under `set -euo pipefail` ([#14](https://github.com/chenrui333/schema-registry-iam/pull/14))
- `scripts/test-image.sh`: Consistent `[[ ]]` bash syntax throughout ([#14](https://github.com/chenrui333/schema-registry-iam/pull/14))

---

## [7.9.6] - 2026-03-25

### Added

- Initial image: `confluentinc/cp-schema-registry:7.9.6` extended with `aws-msk-iam-auth:2.3.5` JAR for MSK IAM authentication
- Multi-arch build: `linux/amd64` and `linux/arm64`
- Digest-pinned base image (`CP_DIGEST`) for reproducible builds
- SHA-256 integrity check for the IAM auth JAR at build time
- Publish to GHCR (`ghcr.io/chenrui333/schema-registry-iam`)
- Automated publishing: push to `main` → `latest` + `<sha>` tags; push `v*` tag → semver tags + GitHub Release
- `justfile` with `build`, `test`, `validate`, and `clean` recipes
- `mise.toml` pinning `just` for reproducible local toolchain
- Renovate for automated dependency updates

---

[Unreleased]: https://github.com/chenrui333/schema-registry-iam/compare/v7.9.6...HEAD
[7.9.6]: https://github.com/chenrui333/schema-registry-iam/releases/tag/v7.9.6
