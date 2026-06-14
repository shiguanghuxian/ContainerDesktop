#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/fixtures/compose/compose.yml"

echo "Cleaning manual test containers..."
container stop cd-manual-container >/dev/null 2>&1 || true
container delete cd-manual-container >/dev/null 2>&1 || true
container-compose -f "${COMPOSE_FILE}" down >/dev/null 2>&1 || true
container delete cdmanualcompose-app >/dev/null 2>&1 || true

echo "Cleaning manual test images..."
container image delete localhost/containerdesktop/cd-manual-image:latest >/dev/null 2>&1 || true
container image delete localhost/containerdesktop/cd-manual-image:copy >/dev/null 2>&1 || true
container image delete localhost/containerdesktop/cd-manual-compose:latest >/dev/null 2>&1 || true

echo "Cleaning temporary archives..."
rm -f /tmp/cd-manual-container-filesystem.tar
rm -f /tmp/cd-manual-image.tar

echo "Remaining manual test resources:"
container ls --all --format json | grep -E 'cd-manual|cdmanualcompose' || true
container image ls --format json | grep -E 'cd-manual|cdmanualcompose' || true
echo "Cleanup complete."

