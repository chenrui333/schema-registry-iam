# schema-registry-iam

Custom Docker image: `confluentinc/cp-schema-registry` + `aws-msk-iam-auth`.
Published to `ghcr.io/chenrui333/schema-registry-iam`.

## Key files

| File | Purpose |
|---|---|
| `Dockerfile` | Image definition — base image + IAM JAR |
| `scripts/test-image.sh` | Local image validation (build, JAR, class loading) |
| `.github/workflows/publish.yml` | `main`/PR build, test, and `latest` publish |
| `.github/workflows/release.yml` | Tag release publish + GitHub Release notes |
| `README.md` | User-facing docs, env vars, consuming the image |
| `CHANGELOG.md` | Release history following Keep a Changelog format |
| `RELEASE.md` | Release runbook — pre-release checklist and tag instructions |
| `justfile` | Local dev commands (`just build`, `just test`, `just lint`, `just clean`) |
| `mise.toml` | Toolchain — pins `just`, `shellcheck`, `hadolint` via mise |
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
   must match what Docker `ADD` downloads (not host curl, which may differ
   due to encoding). Get it by building a probe image:
   ```bash
   docker build --no-cache -f - . <<'EOF'
   FROM confluentinc/cp-schema-registry:<VER>
   ADD https://github.com/aws/aws-msk-iam-auth/releases/download/v<IAM_VER>/aws-msk-iam-auth-<IAM_VER>-all.jar /tmp/iam.jar
   RUN sha256sum /tmp/iam.jar
   EOF
   ```
6. Run `just test` — all checks must pass
7. Commit, tag (`v<IMAGE_VERSION>`), and push

Renovate auto-opens PRs for version bumps. When it bumps `IAM_AUTH_VERSION`,
CI will fail until `IAM_AUTH_JAR_SHA256` is updated (this is intentional —
the checksum prevents publishing an unverified artifact).

## How to run local validation

```bash
just test
```

Or directly: `./scripts/test-image.sh`

Validates: image builds, JAR present on the runtime and preflight classpaths,
IAM classes loadable, and the real entrypoint passes IAM class loading.
Does NOT test live MSK connectivity.

## How publishing works

- Push to `main` → `.github/workflows/publish.yml` builds, tests, publishes `latest` + `<sha>` tags
- Push tag `v*` → `.github/workflows/release.yml` verifies `IMAGE_VERSION`, builds, tests, and publishes semver tags (`8.3.1`, `8.3`) + `latest` + `<sha>`
- **Tag convention**: tags track `IMAGE_VERSION` — `v<IMAGE_VERSION>` (e.g. `v8.3.1`). Major/minor track the compatible Confluent line; patch versions identify image releases and may differ from the embedded Confluent patch.
- Tag releases also create a GitHub Release with generated notes and prepended GHCR pull commands
- Pull requests → build + test only (no push)
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
  `/usr/share/java/schema-registry/`, while Confluent 8.3's `kafka-ready`
  preflight loads it through the symlink in `/usr/share/java/cp-base-java-micro/`.
  Both paths are required.
- **Workflow permissions** — kept minimal (`contents: read`, `packages: write`).
  Do not add unnecessary permissions.
- **OCI labels** — used by GHCR for package metadata display.
