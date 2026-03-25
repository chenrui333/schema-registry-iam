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
4. Run `./scripts/test-image.sh` — all checks must pass
5. Commit, tag (`v<CP_VERSION>`), and push

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

Workflow: `.github/workflows/publish.yml`

## What not to change casually

- **`CP_VERSION` default** — this is the upstream base image version. Only bump
  after verifying the new version exists on Docker Hub and passes validation.
- **`IAM_AUTH_VERSION` default** — the aws-msk-iam-auth release. Verify the
  release artifact URL works before bumping.
- **JAR download path** — `/usr/share/java/schema-registry/` is where the
  Confluent entrypoint expects classpath JARs. Moving it will break class loading.
- **Workflow permissions** — kept minimal (`contents: read`, `packages: write`).
  Do not add unnecessary permissions.
- **OCI labels** — used by GHCR for package metadata display.
