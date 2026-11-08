# Custom Confluent Schema Registry image with AWS MSK IAM auth support.
#
# Layers the aws-msk-iam-auth JAR onto the official Confluent image so
# Schema Registry can authenticate to MSK via IAM instead of SCRAM.
#
# Build:
#   docker build -t schema-registry-iam .
#
# Override versions at build time:
#   docker build --build-arg CP_VERSION=7.9.6 --build-arg IAM_AUTH_VERSION=2.3.5 .

ARG IMAGE_VERSION=8.4.0
ARG CP_VERSION=8.4.0
# Digest of the manifest list for confluentinc/cp-schema-registry:${CP_VERSION}.
# Pin to digest so builds are reproducible even if the tag is re-pushed.
# Update when bumping CP_VERSION:
#   docker buildx imagetools inspect confluentinc/cp-schema-registry:<VER> | grep Digest
ARG CP_DIGEST=sha256:12cd2770fa25df65243dabafd5eef5337ea1145a3cb85afc8a27f7151dfa2999
FROM confluentinc/cp-schema-registry:${CP_VERSION}@${CP_DIGEST}

ARG IMAGE_VERSION
ARG CP_VERSION
ARG CP_DIGEST
ARG IAM_AUTH_VERSION=2.3.9
# SHA-256 of aws-msk-iam-auth-<IAM_AUTH_VERSION>-all.jar as downloaded by
# Docker ADD. Update when bumping IAM_AUTH_VERSION (see CLAUDE.md for how).
ARG IAM_AUTH_JAR_SHA256=922064f312ddc8a5f3dbe65fcef3d02ddbd588a02e3a6f0fca4b5a4dbec1ba43

LABEL org.opencontainers.image.source="https://github.com/chenrui333/schema-registry-iam"
LABEL org.opencontainers.image.description="Confluent Schema Registry with AWS MSK IAM auth"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"
LABEL org.opencontainers.image.base.name="docker.io/confluentinc/cp-schema-registry:${CP_VERSION}@${CP_DIGEST}"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# Download the aws-msk-iam-auth uber-JAR into the Schema Registry classpath.
# Confluent's kafka-ready preflight (8.3 and 8.4) uses cp-base-java-micro
# instead, so the RUN also links the same verified JAR into that classpath.
# ADD lets Docker handle the TLS download; the RUN verifies integrity.
ADD https://github.com/aws/aws-msk-iam-auth/releases/download/v${IAM_AUTH_VERSION}/aws-msk-iam-auth-${IAM_AUTH_VERSION}-all.jar \
    /usr/share/java/schema-registry/aws-msk-iam-auth-${IAM_AUTH_VERSION}-all.jar

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER 0
RUN echo "${IAM_AUTH_JAR_SHA256}  /usr/share/java/schema-registry/aws-msk-iam-auth-${IAM_AUTH_VERSION}-all.jar" | sha256sum -c - \
    && chmod 644 /usr/share/java/schema-registry/aws-msk-iam-auth-${IAM_AUTH_VERSION}-all.jar \
    && ln -s "../schema-registry/aws-msk-iam-auth-${IAM_AUTH_VERSION}-all.jar" \
        "/usr/share/java/cp-base-java-micro/aws-msk-iam-auth-${IAM_AUTH_VERSION}-all.jar"
# Numeric UID of the upstream non-root appuser, matching the base image config
# so Kubernetes runAsNonRoot can verify it.
USER 1000
