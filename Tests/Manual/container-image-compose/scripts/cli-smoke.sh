#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_CONTEXT="${ROOT_DIR}/fixtures/image-build"
COMPOSE_FILE="${ROOT_DIR}/fixtures/compose/compose.yml"

CONTAINER_ID="cd-manual-container"
IMAGE_TAG="localhost/containerdesktop/cd-manual-image:latest"
IMAGE_COPY_TAG="localhost/containerdesktop/cd-manual-image:copy"
COMPOSE_IMAGE="localhost/containerdesktop/cd-manual-compose:latest"
COMPOSE_CONTAINER="cdmanualcompose-app"
CONTAINER_ARCHIVE="/tmp/cd-manual-container-filesystem.tar"
IMAGE_ARCHIVE="/tmp/cd-manual-image.tar"

cleanup() {
  "${ROOT_DIR}/scripts/cleanup.sh" >/dev/null 2>&1 || true
}

trap cleanup EXIT
cleanup

echo "[container] run/list/logs/stats/exec/files/export/start/delete"
container run -d --name "${CONTAINER_ID}" alpine:latest sh -c 'echo cd-manual-container-log-ok; sleep 3600'
sleep 1
container ls --all --format json | grep -q "${CONTAINER_ID}"
container logs -n 20 "${CONTAINER_ID}" | grep -q "cd-manual-container-log-ok"
container stats --format json --no-stream "${CONTAINER_ID}" | grep -q "${CONTAINER_ID}"
test "$(container exec "${CONTAINER_ID}" sh -lc 'printf cd-manual-exec-ok')" = "cd-manual-exec-ok"
container exec "${CONTAINER_ID}" sh -lc 'cat /etc/os-release' | grep -q "NAME="
container stop "${CONTAINER_ID}"
container export -o "${CONTAINER_ARCHIVE}" "${CONTAINER_ID}"
test -s "${CONTAINER_ARCHIVE}"
container start "${CONTAINER_ID}"
sleep 1
container stop "${CONTAINER_ID}"
container delete "${CONTAINER_ID}"

echo "[image] pull/build/tag/save/delete/load"
container image pull alpine:latest
container build -t "${IMAGE_TAG}" --progress plain "${IMAGE_CONTEXT}"
container image inspect "${IMAGE_TAG}" | grep -q "cd-manual-image"
container image tag "${IMAGE_TAG}" "${IMAGE_COPY_TAG}"
container image save -o "${IMAGE_ARCHIVE}" "${IMAGE_COPY_TAG}"
test -s "${IMAGE_ARCHIVE}"
container image delete "${IMAGE_COPY_TAG}"
container image load -i "${IMAGE_ARCHIVE}"
container image ls --format json | grep -q "cd-manual-image"
container image delete "${IMAGE_COPY_TAG}"
container image delete "${IMAGE_TAG}"

echo "[compose] build/up/logs/down"
container-compose -f "${COMPOSE_FILE}" build
container image ls --format json | grep -q "cd-manual-compose"
container-compose -f "${COMPOSE_FILE}" up -d
sleep 1
container ls --all --format json | grep -q "${COMPOSE_CONTAINER}"
container logs -n 20 "${COMPOSE_CONTAINER}" | grep -q "cd-manual-compose-log-ok"
container-compose -f "${COMPOSE_FILE}" down
container ls --all --format json | grep -q "${COMPOSE_CONTAINER}"
container delete "${COMPOSE_CONTAINER}"
container image delete "${COMPOSE_IMAGE}"

rm -f "${CONTAINER_ARCHIVE}" "${IMAGE_ARCHIVE}"
trap - EXIT
cleanup
echo "Manual CLI smoke test passed."

