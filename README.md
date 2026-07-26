# schema-registry-iam

[![Publish](https://github.com/chenrui333/schema-registry-iam/actions/workflows/publish.yml/badge.svg)](https://github.com/chenrui333/schema-registry-iam/actions/workflows/publish.yml)
[![Release](https://github.com/chenrui333/schema-registry-iam/actions/workflows/release.yml/badge.svg)](https://github.com/chenrui333/schema-registry-iam/actions/workflows/release.yml)

Custom Docker image that extends
[`confluentinc/cp-schema-registry`](https://hub.docker.com/r/confluentinc/cp-schema-registry)
with the [aws-msk-iam-auth](https://github.com/aws/aws-msk-iam-auth) library,
enabling Schema Registry to authenticate to Amazon MSK via IAM.

Published to **`ghcr.io/chenrui333/schema-registry-iam`**.

## Pinned versions

| Component | Version | Source |
|---|---|---|
| schema-registry-iam image | `8.3.1` | [GitHub releases](https://github.com/chenrui333/schema-registry-iam/releases) |
| Confluent Platform (Schema Registry) | `8.3.0` | [Docker Hub](https://hub.docker.com/r/confluentinc/cp-schema-registry) |
| aws-msk-iam-auth | `2.3.7` | [GitHub releases](https://github.com/aws/aws-msk-iam-auth/releases) |

Override at build time:

```bash
docker build --build-arg IMAGE_VERSION=8.3.1 --build-arg CP_VERSION=8.3.0 --build-arg IAM_AUTH_VERSION=2.3.7 .
```

## How the image is built

The Dockerfile:

1. Starts `FROM confluentinc/cp-schema-registry:<CP_VERSION>`
2. Downloads the `aws-msk-iam-auth` uber-JAR into the Schema Registry runtime
   classpath at `/usr/share/java/schema-registry/`
3. Links the verified JAR into `/usr/share/java/cp-base-java-micro/`, which
   Confluent 8.3 uses for its `kafka-ready` preflight
4. Sets correct file permissions

No upstream source is forked or patched.

## Build locally

```bash
just build
```

## Validate locally

```bash
just test
```

This verifies:
- Image builds successfully
- `aws-msk-iam-auth` is available to both runtime and preflight classpaths
- `IAMLoginModule` and `IAMClientCallbackHandler` are loadable from each classpath
- The real Confluent entrypoint loads the IAM configuration before reaching Kafka

It does **not** test live MSK connectivity (see [What remains unverified](#what-remains-unverified)).

## Publishing and releases

GitHub Actions uses:

- `.github/workflows/publish.yml` for `main` pushes and pull requests
- `.github/workflows/release.yml` for version tags (`v*`)

| Trigger | Tags produced |
|---|---|
| Push to `main` | `latest`, `<sha>` |
| Push tag `v<IMAGE_VERSION>` | `<IMAGE_VERSION>`, `<major>.<minor>`, `<sha>`, `latest` + GitHub Release |
| Pull request | Build + test only (no push) |

Release tags use the image project's semantic version. Major and minor versions
track the compatible Confluent Platform line; patch versions identify image
releases and may differ from the embedded Confluent patch version. For example,
image `8.3.1` contains Confluent Platform `8.3.0` plus this project's first
packaging fix in the 8.3 line.

Tag releases generate GitHub release notes automatically and prepend GHCR pull
commands such as:

```bash
docker pull ghcr.io/chenrui333/schema-registry-iam:8.3.1
docker pull ghcr.io/chenrui333/schema-registry-iam:8.3
docker pull ghcr.io/chenrui333/schema-registry-iam:latest
```

If GitHub release immutability is enabled for the repository, the published tag
release becomes immutable once the workflow publishes it.

### First-time GHCR setup

After the first successful publish, the package defaults to **private**.
To make it public:

1. Go to `https://github.com/users/chenrui333/packages/container/schema-registry-iam/settings`
2. Scroll to **Danger Zone** → **Change package visibility**
3. Select **Public** and confirm

This is a one-time manual step.

## Consuming the image

```bash
docker pull ghcr.io/chenrui333/schema-registry-iam:latest
```

Or pin to a specific version:

```bash
docker pull ghcr.io/chenrui333/schema-registry-iam:8.3.1
```

## Required IAM environment variables

To connect Schema Registry to an IAM-authenticated MSK cluster, set these
environment variables on your container/task:

```bash
# Kafka bootstrap (IAM-enabled MSK endpoint, port 9098)
SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS=b-1.msk-cluster.xxxx.kafka.us-east-1.amazonaws.com:9098,b-2...

# SASL/IAM config
SCHEMA_REGISTRY_KAFKASTORE_SECURITY_PROTOCOL=SASL_SSL
SCHEMA_REGISTRY_KAFKASTORE_SASL_MECHANISM=AWS_MSK_IAM
SCHEMA_REGISTRY_KAFKASTORE_SASL_JAAS_CONFIG=software.amazon.msk.auth.iam.IAMLoginModule required;
SCHEMA_REGISTRY_KAFKASTORE_SASL_CLIENT_CALLBACK_HANDLER_CLASS=software.amazon.msk.auth.iam.IAMClientCallbackHandler
```

The container/task must also have an IAM role with permissions to connect to the
MSK cluster (at minimum: `kafka-cluster:Connect`, `kafka-cluster:ReadData`,
`kafka-cluster:WriteData`, `kafka-cluster:DescribeTopic`,
`kafka-cluster:CreateTopic` on the `_schemas` topic).

## What remains unverified

This repo validates the image build and classpath. The following require a live
MSK cluster and are **not** tested here:

- IAM authentication handshake with MSK brokers
- `_schemas` topic creation/access via IAM policy
- End-to-end schema registration through the IAM-backed registry
- Schema Registry HA (multi-instance leader election over IAM-auth Kafka)

## Updating versions

[Renovate](https://docs.renovatebot.com/) is configured to automatically open
PRs when new versions of the base image or `aws-msk-iam-auth` are released.

To update manually:

1. Check the latest [cp-schema-registry tags on Docker Hub](https://hub.docker.com/r/confluentinc/cp-schema-registry/tags)
2. Check the latest [aws-msk-iam-auth releases](https://github.com/aws/aws-msk-iam-auth/releases)
3. Set `IMAGE_VERSION` to the next release and update `CP_VERSION` and/or
   `IAM_AUTH_VERSION` when the embedded components change
4. Run `just test` to validate
5. Tag and push: `git tag v<IMAGE_VERSION> && git push origin v<IMAGE_VERSION>`

## License

Apache-2.0
