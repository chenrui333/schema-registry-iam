#!/usr/bin/env bash
# Start a schema-registry-iam image against a local single-node Kafka and
# exercise the REST API.
#
# test-image.sh stops at the entrypoint's kafka-ready preflight. This script
# runs Schema Registry to completion with the IAM JAR on both classpaths, so
# startup and request-handling regressions (classpath conflicts from the
# uber-JAR, permission errors) fail before publishing.
#
# Kafka uses PLAINTEXT: this does NOT test MSK IAM authentication.
#
# Usage:
#   ./scripts/test-runtime.sh [image-ref]

set -euo pipefail

IMAGE="${1:-schema-registry-iam:test}"
KAFKA_IMAGE="apache/kafka:4.4.0@sha256:833b867a9585a141da455dc2b57431c65cbccb27f11c91f694444cca9f777e0f"
STARTUP_TIMEOUT="${STARTUP_TIMEOUT:-180}"

RUN_ID="sri-runtime-$$"
NETWORK="${RUN_ID}"
KAFKA="${RUN_ID}-kafka"
REGISTRY="${RUN_ID}-registry"

cleanup() {
  docker rm -f "${REGISTRY}" "${KAFKA}" >/dev/null 2>&1 || true
  docker network rm "${NETWORK}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  echo "--- Schema Registry log (last 60 lines) ---" >&2
  docker logs --tail 60 "${REGISTRY}" >&2 2>&1 || true
  exit 1
}

echo "=== Starting Kafka (${KAFKA_IMAGE%@*}) ==="
docker network create "${NETWORK}" >/dev/null
docker run -d --name "${KAFKA}" --network "${NETWORK}" --network-alias kafka \
  -e KAFKA_NODE_ID=1 \
  -e KAFKA_PROCESS_ROLES=broker,controller \
  -e KAFKA_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093 \
  -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka:9092 \
  -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  -e KAFKA_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT \
  -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@kafka:9093 \
  -e KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1 \
  -e KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1 \
  -e KAFKA_TRANSACTION_STATE_LOG_MIN_ISR=1 \
  "${KAFKA_IMAGE}" >/dev/null

echo "=== Starting Schema Registry (${IMAGE}) ==="
docker run -d --name "${REGISTRY}" --network "${NETWORK}" \
  -p 127.0.0.1::8081 \
  -e SCHEMA_REGISTRY_HOST_NAME=schema-registry \
  -e SCHEMA_REGISTRY_LISTENERS=http://0.0.0.0:8081 \
  -e SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS=PLAINTEXT://kafka:9092 \
  -e SCHEMA_REGISTRY_CUB_KAFKA_TIMEOUT=120 \
  "${IMAGE}" >/dev/null

PORT_MAPPING=$(docker port "${REGISTRY}" 8081/tcp 2>/dev/null) \
  || fail "Schema Registry exited during startup"
PORT="${PORT_MAPPING##*:}"
PORT="${PORT%%$'\n'*}"
URL="http://127.0.0.1:${PORT}"

echo "=== Waiting for ${URL}/subjects (timeout ${STARTUP_TIMEOUT}s) ==="
deadline=$((SECONDS + STARTUP_TIMEOUT))
until curl -fsS --max-time 5 "${URL}/subjects" >/dev/null 2>&1; do
  if [[ "$(docker inspect -f '{{.State.Running}}' "${REGISTRY}")" != "true" ]]; then
    fail "Schema Registry exited during startup"
  fi
  if (( SECONDS >= deadline )); then
    fail "Schema Registry did not serve ${URL}/subjects within ${STARTUP_TIMEOUT}s"
  fi
  sleep 2
done
echo "PASS: Schema Registry is serving requests"

echo "=== Registering and reading back a schema ==="
SCHEMA='{"type":"record","name":"Smoke","fields":[{"name":"id","type":"string"}]}'
BODY=$(jq -cn --arg schema "${SCHEMA}" '{schema: $schema}')
REGISTERED=$(curl -fsS --max-time 30 -X POST -H 'Content-Type: application/vnd.schemaregistry.v1+json' \
  --data "${BODY}" "${URL}/subjects/runtime-smoke-value/versions") \
  || fail "schema registration request failed"
ID=$(jq -er '.id' <<<"${REGISTERED}") || fail "registration response has no id: ${REGISTERED}"
FETCHED=$(curl -fsS --max-time 10 "${URL}/schemas/ids/${ID}" | jq -er '.schema') \
  || fail "could not fetch schema id ${ID}"
if [[ "$(jq -cS . <<<"${FETCHED}")" != "$(jq -cS . <<<"${SCHEMA}")" ]]; then
  fail "fetched schema ${FETCHED} does not match registered ${SCHEMA}"
fi
echo "PASS: registered and fetched schema id ${ID}"

# Capture the log first: with pipefail, `docker logs | grep -q` reports
# failure when grep exits on the first match and docker logs gets SIGPIPE.
REGISTRY_LOG=$(docker logs "${REGISTRY}" 2>&1)
CLASS_ERRORS=$(grep -E \
  'ClassNotFoundException|NoClassDefFoundError|NoSuchMethodError|LinkageError|UnsupportedClassVersionError' \
  <<<"${REGISTRY_LOG}" || true)
if [[ -n "${CLASS_ERRORS}" ]]; then
  head -20 <<<"${CLASS_ERRORS}" >&2
  fail "Schema Registry log contains class-loading errors"
fi
echo "PASS: no class-loading errors in the Schema Registry log"
