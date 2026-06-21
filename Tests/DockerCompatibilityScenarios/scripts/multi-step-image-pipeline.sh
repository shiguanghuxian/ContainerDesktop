#!/usr/bin/env sh
set -eu

IMAGE="${IMAGE:-local/containerdesktop-compat:latest}"
REGISTRY_IMAGE="${REGISTRY_IMAGE:-registry.example.com/team/containerdesktop-compat:latest}"

docker build --file Dockerfile --tag "$IMAGE" --build-arg VERSION=1.0.0 --label org.opencontainers.image.source=https://example.test/repo --progress=plain .
docker tag "$IMAGE" "$REGISTRY_IMAGE"
docker login --username ci --password-stdin registry.example.com
docker push "$REGISTRY_IMAGE"
docker save -o /tmp/containerdesktop-compat.tar "$IMAGE"
