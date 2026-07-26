#!/usr/bin/env bash
# Validate a schema-registry-iam Docker image.
#
# Checks:
#   1. aws-msk-iam-auth JAR exists in the Schema Registry classpath
#   2. The same JAR is linked into Confluent's kafka-ready classpath
#   3. IAMLoginModule and IAMClientCallbackHandler load on both classpaths
#   4. The real entrypoint reaches Kafka instead of failing class loading
#
# Usage:
#   ./scripts/test-image.sh [--skip-build] [image-tag]
#
# --skip-build  Validate an already-built image without rebuilding.
#               Use this in CI to test the exact image that was built
#               by a prior step.
#
# This does NOT test live MSK connectivity — that requires a running
# MSK cluster with IAM auth enabled.

set -euo pipefail

SKIP_BUILD=false
if [[ "${1:-}" == "--skip-build" ]]; then
  SKIP_BUILD=true
  shift
fi

IMAGE="${1:-schema-registry-iam:test}"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

if [[ "${SKIP_BUILD}" == "false" ]]; then
  echo "=== Building image as ${IMAGE} ==="
  docker build -t "${IMAGE}" . || { fail "docker build"; echo "Build failed — aborting."; exit 1; }
  pass "docker build"
  echo ""
fi

echo "=== Checking aws-msk-iam-auth JAR ==="
JAR_LS=$(docker run --rm --entrypoint sh "${IMAGE}" -c \
  'ls -1 /usr/share/java/schema-registry/aws-msk-iam-auth-*-all.jar 2>/dev/null || true')

if [[ -n "${JAR_LS}" ]]; then
  pass "JAR present: ${JAR_LS}"
else
  fail "aws-msk-iam-auth JAR not found in /usr/share/java/schema-registry/"
fi

echo ""
echo "=== Checking kafka-ready classpath link ==="
if PREFLIGHT_JAR=$(docker run --rm --entrypoint sh "${IMAGE}" -c '
  set -eu
  jar=$(find /usr/share/java/schema-registry -maxdepth 1 -name "aws-msk-iam-auth-*-all.jar" -print -quit)
  link="/usr/share/java/cp-base-java-micro/$(basename "${jar}")"
  test -n "${jar}"
  test -L "${link}"
  test -r "${link}"
  test "$(readlink -f "${link}")" = "${jar}"
  printf "%s\n" "${link}"
'); then
  pass "kafka-ready JAR link: ${PREFLIGHT_JAR}"
else
  fail "aws-msk-iam-auth JAR is not linked into /usr/share/java/cp-base-java-micro/"
fi

echo ""
echo "=== Verifying IAM classes on runtime and preflight classpaths ==="
# When java runs a class that exists but has no suitable main(), it prints
# "Main method not found in class ..." — this confirms the class loaded.
# Any load failure (ClassNotFoundException, NoClassDefFoundError,
# UnsupportedClassVersionError, LinkageError) produces different output.
# We check for the positive "Main method not found" signal.
for CLASSPATH_DIR in /usr/share/java/schema-registry \
                     /usr/share/java/cp-base-java-micro; do
  for CLASS in software.amazon.msk.auth.iam.IAMLoginModule \
               software.amazon.msk.auth.iam.IAMClientCallbackHandler; do
    OUTPUT=$(docker run --rm --entrypoint sh "${IMAGE}" -c \
      "java -cp '${CLASSPATH_DIR}/*' ${CLASS} 2>&1 || true")
    if grep -q "Main method not found" <<<"${OUTPUT}"; then
      pass "class loadable from ${CLASSPATH_DIR}: ${CLASS}"
    else
      fail "class not loadable from ${CLASSPATH_DIR}: ${CLASS}"
      echo "  Output: $(echo "${OUTPUT}" | head -3)" >&2
    fi
  done
done

echo ""
echo "=== Running Confluent entrypoint preflight ==="
ENTRYPOINT_STATUS=0
ENTRYPOINT_OUTPUT=$(docker run --rm --network none \
  -e SCHEMA_REGISTRY_HOST_NAME=127.0.0.1 \
  -e SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS=127.0.0.1:9098 \
  -e SCHEMA_REGISTRY_KAFKASTORE_SECURITY_PROTOCOL=SASL_SSL \
  -e SCHEMA_REGISTRY_KAFKASTORE_SASL_MECHANISM=AWS_MSK_IAM \
  -e 'SCHEMA_REGISTRY_KAFKASTORE_SASL_JAAS_CONFIG=software.amazon.msk.auth.iam.IAMLoginModule required;' \
  -e SCHEMA_REGISTRY_KAFKASTORE_SASL_CLIENT_CALLBACK_HANDLER_CLASS=software.amazon.msk.auth.iam.IAMClientCallbackHandler \
  -e SCHEMA_REGISTRY_CUB_KAFKA_TIMEOUT=1 \
  -e AWS_ACCESS_KEY_ID=test \
  -e AWS_SECRET_ACCESS_KEY=test \
  -e AWS_REGION=us-east-1 \
  -e AWS_EC2_METADATA_DISABLED=true \
  "${IMAGE}" 2>&1) || ENTRYPOINT_STATUS=$?

if [[ "${ENTRYPOINT_STATUS}" -ne 0 ]] \
  && grep -q "Check if Kafka is healthy" <<<"${ENTRYPOINT_OUTPUT}" \
  && grep -q "kafka-ready check failed" <<<"${ENTRYPOINT_OUTPUT}" \
  && ! grep -Eq \
    'ClassNotFoundException|NoClassDefFoundError|Class .* could not be found' \
    <<<"${ENTRYPOINT_OUTPUT}"; then
  pass "entrypoint loaded IAM classes and reached the expected Kafka timeout"
else
  fail "entrypoint did not complete the IAM class-loading preflight"
  head -30 <<<"${ENTRYPOINT_OUTPUT}" >&2
fi

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[ "${FAIL}" -eq 0 ] || exit 1
