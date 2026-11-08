# schema-registry-iam

Custom Docker image: `confluentinc/cp-schema-registry` + `aws-msk-iam-auth`.
Published to `ghcr.io/chenrui333/schema-registry-iam`.

## Key files

| File | Purpose |
|---|---|
| `Dockerfile` | Image definition — base image + IAM JAR |
| `scripts/test-image.sh` | Image validation (JAR, classpaths, user, entrypoint preflight) on each architecture |
| `scripts/test-runtime.sh` | Runtime smoke test: Schema Registry against a local PLAINTEXT Kafka, register and fetch a schema |
| `.github/workflows/publish.yml` | `main`/PR build, test, and `latest` publish |
| `.github/workflows/release.yml` | Tag release publish + GitHub Release notes |
| `README.md` | User-facing docs, env vars, consuming the image |
| `CHANGELOG.md` | Release history following Keep a Changelog format |
| `RELEASE.md` | Release runbook — pre-release checklist and tag instructions |
| `justfile` | Local dev commands (`just build`, `just test`, `just validate`, `just lint`, `just clean`) |
| `mise.toml` | Toolchain — pins `just`, `shellcheck`, `hadolint`, `actionlint`, `zizmor` via mise |
| `renovate.json` | Automated dependency updates for base image and IAM JAR |

## How to update to a new upstream release

1. Check latest `confluentinc/cp-schema-registry` tag on Docker Hub
2. Check latest `aws-msk-iam-auth` release on GitHub
3. Set `IMAGE_VERSION` to the next release and update `CP_VERSION` and/or
   `IAM_AUTH_VERSION` when the embedded components change
4. If `CP_VERSION` changed, update `CP_DIGEST`:
   ```bash
   docker buildx imagetools inspect confluentinc/cp-schema-registry:<VER> | grep Digest
   ```
5. If `IAM_AUTH_VERSION` changed, update `IAM_AUTH_JAR_SHA256`. The checksum
   must match the bytes Docker `ADD` downloads (not a host-side download).
   `ADD --checksum` verifies it: after setting the new `IAM_AUTH_VERSION` in
   the Dockerfile (step 3), build with BuildKit and keep the old checksum. The
   build fails with the downloaded digest first:
   ```bash
   docker build --no-cache .
   # ERROR: digest mismatch sha256:<downloaded>: sha256:<expected>
   ```
   Any other build error means the download itself failed; fix that first.
6. Run `just test` — all checks must pass
7. Commit and merge to `main`, then tag as described in `RELEASE.md`

Renovate auto-opens PRs for version bumps. A `CP_VERSION` PR also updates
`CP_DIGEST`; a re-pushed upstream tag produces a digest-only PR. When it bumps
`IAM_AUTH_VERSION`, CI will fail until `IAM_AUTH_JAR_SHA256` is updated (this
is intentional — `ADD --checksum` prevents publishing an unverified artifact).
None of these automerge: decide whether the change needs an `IMAGE_VERSION`
release as described in `RELEASE.md`.

## How to run local validation

```bash
just test
```

Or directly: `./scripts/test-image.sh` and `./scripts/test-runtime.sh <image>`.

Validates: image builds, JAR present on the runtime and preflight classpaths,
IAM classes loadable, the real entrypoint passes IAM class loading, and
Schema Registry starts against a local Kafka and serves register/fetch
requests. CI runs the runtime smoke test on amd64 only.
Does NOT test live MSK connectivity or IAM authentication.

## How publishing works

- Push to `main` → `.github/workflows/publish.yml` lints, builds, tests, publishes `latest` + `<sha>` tags
- Push tag `v*` → `.github/workflows/release.yml` verifies `IMAGE_VERSION`, builds, tests, and publishes semver tags (`8.3.1`, `8.3`) + `latest` + `<sha>`
- **Tag convention**: tags track `IMAGE_VERSION` — `v<IMAGE_VERSION>` (e.g. `v8.3.1`). Major/minor track the compatible Confluent line; patch versions identify image releases and may differ from the embedded Confluent patch.
- Tag releases also create a GitHub Release with generated notes and prepended GHCR pull commands
- Pull requests → lint, build + test only (no push)
- The `lint` job runs `just lint` with the `mise.toml` tool versions; `build-and-publish` (build + test, read-only token, a required check) needs it; the push-only `publish` job needs `build-and-publish` and alone holds `packages: write`
- Published images are multi-arch (`linux/amd64`, `linux/arm64`)
- If repository-level immutable releases are enabled, published GitHub Releases become immutable after creation

## What not to change casually

- **`IMAGE_VERSION` default** — the image project's release version. Every tag
  must match it exactly; never reuse an already-published version.
- **`CP_VERSION` default** — this is the upstream base image version. Only bump
  after verifying the new version exists on Docker Hub and passes validation.
- **`CP_DIGEST`** — digest-pin for the base image. Must be updated whenever
  `CP_VERSION` changes. The digest ensures builds are reproducible even if
  the upstream tag is re-pushed.
- **`IAM_AUTH_VERSION` default** — the aws-msk-iam-auth release. Must update
  `IAM_AUTH_JAR_SHA256` in the same commit.
- **`IAM_AUTH_JAR_SHA256`** — integrity check for the downloaded JAR. Build
  fails if this doesn't match. Never remove or skip the verification.
- **JAR classpaths** — Schema Registry loads the JAR from
  `/usr/share/java/schema-registry/`, while the `kafka-ready` preflight in
  Confluent 8.3 and 8.4 (`UB_DEFAULT_CLASSPATH`) loads it through the symlink in
  `/usr/share/java/cp-base-java-micro/`. Both paths are required.
- **Final image user** — `USER 1000` (upstream `appuser`), numeric like the
  base image so Kubernetes `runAsNonRoot` works. `just test` asserts it.
- **Workflow permissions** — `permissions: {}` at workflow level; jobs get only
  what they use. `packages: write` only in push/tag publishing jobs, never in
  jobs that run for pull requests; only the release workflow's
  `github-release` job has `contents: write`. `zizmor` in `just lint` checks
  this.
- **OCI labels** — used by GHCR for package metadata display.
