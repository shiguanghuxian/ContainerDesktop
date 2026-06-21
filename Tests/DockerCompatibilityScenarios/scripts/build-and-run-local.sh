#!/usr/bin/env sh
set -eu

IMAGE="${IMAGE:-local/containerdesktop-compat:dev}"
NAME="${NAME:-containerdesktop-compat-web}"

docker build -t "$IMAGE" .
docker run --rm --detach --name "$NAME" --publish 8080:80 --env NODE_ENV=production --volume /tmp/app:/app --workdir /app "$IMAGE" npm start
docker logs --tail=50 "$NAME"
docker stop "$NAME"
docker rm -f "$NAME"
