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

ARG CP_VERSION=8.3.0
# Digest of the manifest list for confluentinc/cp-schema-registry:${CP_VERSION}.
# Pin to digest so builds are reproducible even if the tag is re-pushed.
# Update when bumping CP_VERSION:
#   docker buildx imagetools inspect confluentinc/cp-schema-registry:<VER> | grep Digest
ARG CP_DIGEST=sha256:d9e6f3d1142598906a51dca66b8b1251bb0bc24ba7faae1836d7c642fc4d70ea
FROM confluentinc/cp-schema-registry:${CP_VERSION}@${CP_DIGEST}

ARG CP_VERSION
ARG IAM_AUTH_VERSION=2.3.7
# SHA-256 of aws-msk-iam-auth-<IAM_AUTH_VERSION>-all.jar as downloaded by
# Docker ADD. Update when bumping IAM_AUTH_VERSION (see CLAUDE.md for how).
ARG IAM_AUTH_JAR_SHA256=a46aff030edf9451c098ffb2a73938a9edec6e8d98b00daf4117738eda418309

LABEL org.opencontainers.image.source="https://github.com/chenrui333/schema-registry-iam"
LABEL org.opencontainers.image.description="Confluent Schema Registry with AWS MSK IAM auth"
LABEL org.opencontainers.image.version="${CP_VERSION}-iam${IAM_AUTH_VERSION}"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# Download the aws-msk-iam-auth uber-JAR into the Schema Registry classpath.
# The /usr/share/java/schema-registry/ directory is automatically included
# on the Schema Registry classpath by the Confluent Docker entrypoint.
# ADD lets Docker handle the TLS download; the RUN verifies integrity.
ADD https://github.com/aws/aws-msk-iam-auth/releases/download/v${IAM_AUTH_VERSION}/aws-msk-iam-auth-${IAM_AUTH_VERSION}-all.jar \
    /usr/share/java/schema-registry/aws-msk-iam-auth-${IAM_AUTH_VERSION}-all.jar

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root
RUN echo "${IAM_AUTH_JAR_SHA256}  /usr/share/java/schema-registry/aws-msk-iam-auth-${IAM_AUTH_VERSION}-all.jar" | sha256sum -c - \
    && chmod 644 /usr/share/java/schema-registry/aws-msk-iam-auth-${IAM_AUTH_VERSION}-all.jar
USER appuser
