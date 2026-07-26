# Repository Instructions

## Project scope

This repository publishes `ghcr.io/chenrui333/schema-registry-iam`, a
multi-architecture Confluent Schema Registry image with AWS MSK IAM support.
Keep changes focused on image construction, validation, publishing, and the
documentation that describes those behaviors.

Read [README.md](README.md) for the user contract and [RELEASE.md](RELEASE.md)
before changing versions or release automation. [CLAUDE.md](CLAUDE.md) contains
the deeper checksum and digest maintenance procedure.

## Version and dependency contract

- `IMAGE_VERSION` is this project's semantic version. Git release tags must
  exactly match it as `v<IMAGE_VERSION>`.
- Major and minor image versions track the compatible Confluent Platform line.
  Patch versions identify releases of this image and may differ from the
  embedded Confluent patch version.
- `CP_VERSION` and `CP_DIGEST` identify the Confluent base image and must be
  updated together.
- `IAM_AUTH_VERSION` and `IAM_AUTH_JAR_SHA256` identify the AWS MSK IAM auth JAR
  and must be updated together.
- Never reuse an existing GitHub Release or exact GHCR image version. Choose the
  next patch version for packaging-only fixes.

## Image invariants

- Keep the Confluent base image digest-pinned and verify downloaded JAR content
  before it becomes part of the image.
- Keep the IAM JAR in `/usr/share/java/schema-registry/` for Schema Registry and
  linked into `/usr/share/java/cp-base-java-micro/` for Confluent's
  `kafka-ready` preflight. Both classpaths are required.
- Run the final image as `appuser`; use root only for build-time installation
  and permissions.
- Preserve both `linux/amd64` and `linux/arm64` builds in CI and releases.
- Do not weaken the real-entrypoint regression test into a classpath-only test.
  The expected offline result is successful IAM class loading followed by the
  deliberately unreachable Kafka timeout.

## Required validation

Run the relevant checks before pushing:

```bash
just lint
just test
actionlint .github/workflows/publish.yml .github/workflows/release.yml
git diff --check
```

The local test does not prove a live MSK IAM handshake. Changes affecting
authentication or startup must also be verified in an IAM-enabled integration
environment before being promoted.

## Pull requests and releases

- Keep commits narrow and include a DCO `Signed-off-by` trailer.
- Update `CHANGELOG.md` and the pinned-version documentation when preparing an
  image release. Update `RELEASE.md` when the release contract changes.
- Treat successful checks on an older commit as stale; verify the exact PR head
  after every push.
- Resolve review findings only after verifying them against the current code.
- Follow [RELEASE.md](RELEASE.md) to cut a tag, then verify the tag workflow,
  GitHub Release, GHCR tags, multi-architecture manifest, and published image.
