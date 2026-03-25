# schema-registry-iam

Custom Docker image: `confluentinc/cp-schema-registry` + `aws-msk-iam-auth`.
Published to `ghcr.io/chenrui333/schema-registry-iam`.

## Key files

| File | Purpose |
|---|---|
| `Dockerfile` | Image definition — base image + IAM JAR |
| `scripts/test-image.sh` | Local image validation (build, JAR, class loading) |
| `.github/workflows/publish.yml` | GHCR publish on tag push and main merge |
| `README.md` | User-facing docs, env vars, consuming the image |
| `justfile` | Local dev commands (`just build`, `just test`, `just clean`) |
| `mise.toml` | Toolchain — pins `just` via mise |
| `renovate.json` | Automated dependency updates for base image and IAM JAR |

## How to update to a new upstream release

1. Check latest `confluentinc/cp-schema-registry` tag on Docker Hub
2. Check latest `aws-msk-iam-auth` release on GitHub
3. Update `CP_VERSION` and/or `IAM_AUTH_VERSION` ARG defaults in `Dockerfile`
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
7. Commit, tag (`v<CP_VERSION>`), and push

Renovate auto-opens PRs for version bumps. When it bumps `IAM_AUTH_VERSION`,
CI will fail until `IAM_AUTH_JAR_SHA256` is updated (this is intentional —
the checksum prevents publishing an unverified artifact).

## How to run local validation

```bash
just test
```

Or directly: `./scripts/test-image.sh`

Validates: image builds, JAR present, IAM classes loadable.
Does NOT test live MSK connectivity.

## How publishing works

- Push to `main` → builds, tests, publishes `latest` + `<sha>` tags
- Push tag `v*` → publishes semver tags (`7.9.6`, `7.9`) + `latest` + `<sha>`
- Pull requests → build + test only (no push)
- Published images are multi-arch (`linux/amd64`, `linux/arm64`)

Workflow: `.github/workflows/publish.yml`

## What not to change casually

- **`CP_VERSION` default** — this is the upstream base image version. Only bump
  after verifying the new version exists on Docker Hub and passes validation.
- **`CP_DIGEST`** — digest-pin for the base image. Must be updated whenever
  `CP_VERSION` changes. The digest ensures builds are reproducible even if
  the upstream tag is re-pushed.
- **`IAM_AUTH_VERSION` default** — the aws-msk-iam-auth release. Must update
  `IAM_AUTH_JAR_SHA256` in the same commit.
- **`IAM_AUTH_JAR_SHA256`** — integrity check for the downloaded JAR. Build
  fails if this doesn't match. Never remove or skip the verification.
- **JAR download path** — `/usr/share/java/schema-registry/` is where the
  Confluent entrypoint expects classpath JARs. Moving it will break class loading.
- **Workflow permissions** — kept minimal (`contents: read`, `packages: write`).
  Do not add unnecessary permissions.
- **OCI labels** — used by GHCR for package metadata display.
