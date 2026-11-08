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
| schema-registry-iam image | `8.4.0` | [GitHub releases](https://github.com/chenrui333/schema-registry-iam/releases) |
| Confluent Platform (Schema Registry) | `8.4.0` | [Docker Hub](https://hub.docker.com/r/confluentinc/cp-schema-registry) |
| aws-msk-iam-auth | `2.3.9` | [GitHub releases](https://github.com/aws/aws-msk-iam-auth/releases) |

Override at build time. `CP_VERSION` and `CP_DIGEST`, and `IAM_AUTH_VERSION`
and `IAM_AUTH_JAR_SHA256`, must change together; see [CLAUDE.md](CLAUDE.md)
for how to derive the digest and checksum:

```bash
docker build \
  --build-arg IMAGE_VERSION=<image-version> \
  --build-arg CP_VERSION=<cp-version> --build-arg CP_DIGEST=sha256:<manifest-list-digest> \
  --build-arg IAM_AUTH_VERSION=<iam-version> --build-arg IAM_AUTH_JAR_SHA256=<jar-sha256> \
  .
```

## How the image is built

The Dockerfile:

1. Starts `FROM confluentinc/cp-schema-registry:<CP_VERSION>`
2. Downloads the `aws-msk-iam-auth` uber-JAR into the Schema Registry runtime
   classpath at `/usr/share/java/schema-registry/` with `ADD --checksum`, so
   the build fails unless the bytes match `IAM_AUTH_JAR_SHA256`
3. Links the verified JAR into `/usr/share/java/cp-base-java-micro/`, which
   Confluent 8.3 and 8.4 use for their `kafka-ready` preflight
4. Restores the upstream numeric non-root user (`1000`, `appuser`)

No upstream source is forked or patched.

## Build locally

```bash
just build
```

Requires BuildKit (the default `docker build` builder since Docker Engine 23,
or `docker buildx build`). The Dockerfile pins its frontend with a `# syntax`
directive; the legacy builder (`DOCKER_BUILDKIT=0`) is not supported.

## Validate locally

```bash
just test
```

This verifies:
- Image builds successfully
- `aws-msk-iam-auth` is available to both runtime and preflight classpaths
- `IAMLoginModule` and `IAMClientCallbackHandler` are loadable from each classpath
- The real Confluent entrypoint loads the IAM configuration before reaching Kafka
- Schema Registry starts against a local PLAINTEXT Kafka
  (`scripts/test-runtime.sh`), registers a schema, and reads it back without
  class-loading errors

It does **not** test live MSK connectivity or IAM authentication (see
[What remains unverified](#what-remains-unverified)).

## Publishing and releases

GitHub Actions uses:

- `.github/workflows/publish.yml` for `main` pushes and pull requests
- `.github/workflows/release.yml` for version tags (`v*`)

| Trigger | Tags produced |
|---|---|
| Push to `main` | `latest`, `<sha>` |
| Push tag `v<IMAGE_VERSION>` | `<IMAGE_VERSION>`, `<major>.<minor>`, `<sha>`, `latest` + GitHub Release |
| Pull request | Lint, build + test only (no push) |

Release tags use the image project's semantic version. Major and minor versions
track the compatible Confluent Platform line; patch versions identify image
releases and may differ from the embedded Confluent patch version. For example,
image `8.3.1` contains Confluent Platform `8.3.0` plus this project's first
packaging fix in the 8.3 line.

Tag releases generate GitHub release notes automatically and prepend GHCR pull
commands such as:

```bash
docker pull ghcr.io/chenrui333/schema-registry-iam:8.4.0
docker pull ghcr.io/chenrui333/schema-registry-iam:8.4
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
docker pull ghcr.io/chenrui333/schema-registry-iam:8.4.0
```

## Configuring MSK IAM authentication

This image authenticates **Schema Registry to Kafka**, not REST clients to
Schema Registry. All callers use the registry's AWS role for Kafka operations;
their identities are not forwarded to MSK. The default REST listener is
unauthenticated HTTP. Restrict access with network controls, and configure
[REST authentication and HTTPS](https://docs.confluent.io/platform/current/schema-registry/security/index.html)
or an authenticated TLS proxy before exposing it to untrusted clients. Broker
IAM permissions do not provide per-user or per-subject REST authorization.

Set these literal environment values on the container or task (for example in
a Docker `--env-file` file, not as unquoted shell assignments). The upstream
entrypoint also requires `SCHEMA_REGISTRY_HOST_NAME`.

```text
SCHEMA_REGISTRY_HOST_NAME=<address other instances use to reach this one>
SCHEMA_REGISTRY_LISTENERS=http://0.0.0.0:8081

# IAM-enabled MSK bootstrap brokers (port 9098)
SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS=b-1.msk-cluster.xxxx.kafka.us-east-1.amazonaws.com:9098,b-2...

# SASL/IAM config
SCHEMA_REGISTRY_KAFKASTORE_SECURITY_PROTOCOL=SASL_SSL
SCHEMA_REGISTRY_KAFKASTORE_SASL_MECHANISM=AWS_MSK_IAM
SCHEMA_REGISTRY_KAFKASTORE_SASL_JAAS_CONFIG=software.amazon.msk.auth.iam.IAMLoginModule required;
SCHEMA_REGISTRY_KAFKASTORE_SASL_CLIENT_CALLBACK_HANDLER_CLASS=software.amazon.msk.auth.iam.IAMClientCallbackHandler
```

The IAM login module signs requests with credentials from the
[AWS default credential provider chain](https://github.com/aws/aws-msk-iam-auth#configuring-a-kafka-client-to-use-aws-iam-with-aws_msk_iam-mechanism)
(for example an ECS task role, EKS IRSA, or an EC2 instance profile). To assume
a dedicated role, set:

```text
SCHEMA_REGISTRY_KAFKASTORE_SASL_JAAS_CONFIG=software.amazon.msk.auth.iam.IAMLoginModule required awsRoleArn="arn:aws:iam::<account>:role/<msk-role>" awsRoleSessionName="schema-registry" awsAddDefaultProviders="false";
```

The workload role needs `sts:AssumeRole` permission and the target role must
trust it. `awsAddDefaultProviders="false"` prevents falling back to the default
credential chain if assuming that role fails; otherwise authentication could
succeed as a different principal. Prefer workload roles over static access
keys; never bake credentials into the image.

Credential providers that generate a new session name on refresh, such as EKS
Pod Identity, can make re-authentication fail with
`Cannot change principals during re-authentication`; the fixed
`awsRoleSessionName` above is the
[upstream workaround](https://github.com/aws/aws-msk-iam-auth#failure-during-re-authentication-due-to-session-name-change-eks-pod-identityother-credential-providers).

### IAM policy

Schema Registry needs these MSK actions. With default settings:

| Resource | Actions | Why |
|---|---|---|
| Cluster | `kafka-cluster:Connect` | Authenticate to the brokers |
| Cluster | `kafka-cluster:WriteDataIdempotently` | The `_schemas` producer sets `enable.idempotence=true` |
| Topic `_schemas` | `kafka-cluster:CreateTopic` | Create the topic on first start (omit if you pre-create it as a compacted, single-partition topic) |
| Topic `_schemas` | `kafka-cluster:DescribeTopic`, `kafka-cluster:DescribeTopicDynamicConfiguration` | Find the topic and verify `cleanup.policy=compact` on every later start |
| Topic `_schemas` | `kafka-cluster:ReadData`, `kafka-cluster:WriteData` | Read and append schemas |
| Groups `schema-registry*` | `kafka-cluster:DescribeGroup`, `kafka-cluster:AlterGroup` | Leader election joins group `schema-registry`; the store reader's consumer uses `group.id` `schema-registry-<host>-<port>`; MSK requires `AlterGroup` with `ReadData` |

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["kafka-cluster:Connect", "kafka-cluster:WriteDataIdempotently"],
      "Resource": "arn:aws:kafka:<region>:<account>:cluster/<cluster-name>/<cluster-uuid>"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kafka-cluster:CreateTopic",
        "kafka-cluster:DescribeTopic",
        "kafka-cluster:DescribeTopicDynamicConfiguration",
        "kafka-cluster:ReadData",
        "kafka-cluster:WriteData"
      ],
      "Resource": "arn:aws:kafka:<region>:<account>:topic/<cluster-name>/<cluster-uuid>/_schemas"
    },
    {
      "Effect": "Allow",
      "Action": ["kafka-cluster:DescribeGroup", "kafka-cluster:AlterGroup"],
      "Resource": "arn:aws:kafka:<region>:<account>:group/<cluster-name>/<cluster-uuid>/schema-registry*"
    }
  ]
}
```

If you pre-create `_schemas` (one partition, `cleanup.policy=compact`), remove
`kafka-cluster:CreateTopic` from the topic statement. If you set
`SCHEMA_REGISTRY_KAFKASTORE_TOPIC`,
`SCHEMA_REGISTRY_SCHEMA_REGISTRY_GROUP_ID`, or
`SCHEMA_REGISTRY_KAFKASTORE_GROUP_ID`, change the topic and group ARNs to
match. Idempotent (non-transactional) writes need no transactional-ID
permissions.
This list comes from the Schema Registry 8.4 source (`KafkaStore`,
`KafkaStoreReaderThread`, `SchemaRegistryConfig`) and the
[MSK IAM action semantics](https://docs.aws.amazon.com/msk/latest/developerguide/kafka-actions.html);
it has not been verified against a live cluster here.

### Troubleshooting

| Symptom | Likely cause |
|---|---|
| Startup stops at `Check if Kafka is healthy` / `kafka-ready check failed` | Network path to port 9098, or `kafka-cluster:Connect` denied (check the Kafka log lines above it) |
| `SaslAuthenticationException: Access denied` | No usable AWS credentials, wrong role, or `Connect` not allowed on this cluster ARN |
| `Failed trying to create or validate schema topic configuration` | Missing `CreateTopic`, `DescribeTopic`, or `DescribeTopicDynamicConfiguration` on the topic |
| `ClusterAuthorizationException` when registering a schema | Missing `WriteDataIdempotently` on the cluster |
| `GroupAuthorizationException`, or no instance becomes leader | Missing `DescribeGroup`/`AlterGroup` on the `schema-registry*` groups |
| `ClassNotFoundException: software.amazon.msk.auth.iam.IAMLoginModule` | Running the upstream Confluent image instead of this one |

## What remains unverified

The tests validate the image, classpaths, and a REST register/read round trip
against local PLAINTEXT Kafka. The following require a live MSK cluster and
are **not** tested here:

- IAM authentication handshake with MSK brokers
- `_schemas` topic creation/access via IAM policy, including the policy above
- End-to-end schema registration through the IAM-backed registry
- Schema Registry HA (multi-instance leader election over IAM-auth Kafka)

## Updating versions

[Renovate](https://docs.renovatebot.com/) opens PRs when new versions of the
base image or `aws-msk-iam-auth` are released. Base image version PRs update
`CP_VERSION` and `CP_DIGEST` together, and a re-pushed upstream tag produces a
digest-only PR; `aws-msk-iam-auth` PRs need a manual `IAM_AUTH_JAR_SHA256`
update. None of them automerge.

To update manually, follow [CLAUDE.md](CLAUDE.md) for the version, digest, and
checksum changes, then [RELEASE.md](RELEASE.md) to update `CHANGELOG.md`,
merge to `main`, and tag the release.

## License

Apache-2.0
