# Repository Instructions

## Sources of truth

Read [README.md](README.md) for the consumer contract, [RELEASE.md](RELEASE.md)
before changing versions or release automation, and [CLAUDE.md](CLAUDE.md) for
the checksum and digest procedures. Update the relevant document in the same
change when image startup, classpath, publishing, or release behavior changes.

## Version and artifact guardrails

- Treat `CP_VERSION` and `CP_DIGEST` as one change. `CP_DIGEST` is the manifest
  list digest reported by `docker buildx imagetools inspect`; never replace the
  digest-pinned base image with a mutable tag-only reference.
- Treat `IAM_AUTH_VERSION` and `IAM_AUTH_JAR_SHA256` as one change. The checksum
  must cover the exact bytes fetched by Docker `ADD --checksum`; derive it from
  the build's `digest mismatch` error as described in [CLAUDE.md](CLAUDE.md),
  not from a host-side download.
- Renovate changes `CP_VERSION` and `CP_DIGEST` together through one regex
  manager (the dockerfile manager is disabled for the base image), opens a
  digest-only PR when the upstream tag is re-pushed, and changes only
  `IAM_AUTH_VERSION` for the IAM JAR. Its Dockerfile custom-manager PRs
  intentionally do not automerge. Supply the companion checksum instead of
  weakening the failing integrity gate.
- Exception: Renovate may automerge the test-only `KAFKA_IMAGE` in
  `scripts/test-runtime.sh`; CI runs the smoke test against the update.
- `IMAGE_VERSION` is this image's release version, not the embedded Confluent
  version. Keep its major/minor line compatible with Confluent, use an unused
  patch version for packaging-only fixes, and tag it exactly as
  `v<IMAGE_VERSION>`.
- Never move or reuse a release tag, GitHub Release, or exact GHCR version tag.
  A release tag must point to the `main` commit containing its changelog entry.

## Image and test invariants

- Install one verified IAM JAR under `/usr/share/java/schema-registry/` and link
  that same file into `/usr/share/java/cp-base-java-micro/`; do not create a
  separately downloaded or unverified preflight copy.
- When changing the Confluent major/minor line, re-check the upstream
  `kafka-ready` classpath (`UB_DEFAULT_CLASSPATH`) and real entrypoint behavior.
  Do not assume the 8.3/8.4 preflight path remains valid in a later line.
- Keep `appuser` as the final image user, by numeric UID (`USER 1000`) to match
  the base image; switch to root (`USER 0`) only for installation and
  permission changes.
- Preserve the real-entrypoint regression test. An offline pass requires a
  nonzero exit at the deliberately unreachable Kafka check with no class,
  linkage, or Java-version error; a standalone classpath probe is not enough.
- In CI, validate each loaded architecture image with `--skip-build` so the test
  cannot silently rebuild a different artifact. Test both `linux/amd64` and
  `linux/arm64` before publishing the multi-architecture manifest.
- Keep the amd64 runtime smoke test (`scripts/test-runtime.sh`) before
  publishing. It proves Schema Registry starts and serves requests with the IAM
  JAR on its classpath; keep `KAFKA_IMAGE` digest-pinned.
- Local and PR tests do not prove an IAM handshake, `_schemas` access, or HA.
  Do not claim those behaviors are verified without an IAM-enabled MSK test.

## Workflow guardrails

- Pin third-party actions to full commit SHAs and keep
  `actions/checkout` credentials disabled with `persist-credentials: false`.
- Keep job permissions minimal. `contents: write` belongs only in the release
  job; do not broaden repository or package permissions to fix an unrelated
  workflow failure.
- Keep PR workflows build-and-test only. Publishing is limited to `main` pushes
  and release tags.
- Preserve the concurrency policy: superseded PR runs may be canceled, but
  `main` publish runs must queue rather than cancel one another.

## Validation by change type

- Dockerfile or test script: `just lint && just test`.
- GitHub Actions: `actionlint .github/workflows/*.yml`. `actionlint` is not
  supplied by `mise.toml` and must be installed separately.
- Every change: `git diff --check`.

Before merging, verify `build-and-publish` passed for the current PR head.
Commits must include a DCO `Signed-off-by` trailer.
