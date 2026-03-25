#!/usr/bin/env bash
# Validate the schema-registry-iam Docker image.
#
# Checks:
#   1. Image builds successfully
#   2. aws-msk-iam-auth JAR exists in the expected classpath directory
#   3. IAMLoginModule and IAMClientCallbackHandler classes are loadable
#
# Usage:
#   ./scripts/test-image.sh [image-tag]
#
# This does NOT test live MSK connectivity — that requires a running
# MSK cluster with IAM auth enabled.

set -euo pipefail

IMAGE="${1:-schema-registry-iam:test}"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }

echo "=== Building image as ${IMAGE} ==="
docker build -t "${IMAGE}" . || { fail "docker build"; echo "Build failed — aborting."; exit 1; }
pass "docker build"

echo ""
echo "=== Checking aws-msk-iam-auth JAR ==="
JAR_LS=$(docker run --rm --entrypoint sh "${IMAGE}" -c \
  'ls -1 /usr/share/java/schema-registry/aws-msk-iam-auth-*-all.jar 2>/dev/null')

if [ -n "${JAR_LS}" ]; then
  pass "JAR present: ${JAR_LS}"
else
  fail "aws-msk-iam-auth JAR not found in /usr/share/java/schema-registry/"
fi

echo ""
echo "=== Verifying IAM classes on classpath ==="
# When java runs a class that exists but has no suitable main(), it prints
# "Main method not found in class ..." — this confirms the class loaded.
# Any load failure (ClassNotFoundException, NoClassDefFoundError,
# UnsupportedClassVersionError, LinkageError) produces different output.
# We check for the positive "Main method not found" signal.
for CLASS in software.amazon.msk.auth.iam.IAMLoginModule \
             software.amazon.msk.auth.iam.IAMClientCallbackHandler; do
  OUTPUT=$(docker run --rm --entrypoint sh "${IMAGE}" -c \
    "java -cp '/usr/share/java/schema-registry/*' ${CLASS} 2>&1 || true")
  if echo "${OUTPUT}" | grep -q "Main method not found"; then
    pass "class loadable: ${CLASS}"
  else
    fail "class not loadable: ${CLASS}"
    echo "  Output: $(echo "${OUTPUT}" | head -3)" >&2
  fi
done

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[ "${FAIL}" -eq 0 ] || exit 1
