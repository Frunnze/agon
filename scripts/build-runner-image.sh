#!/bin/sh
set -eu

SCRIPTS_DIRECTORY=$(cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIRECTORY=$(dirname -- "$SCRIPTS_DIRECTORY")
IMAGE_DIRECTORY="$PROJECT_DIRECTORY/runner-image"
IMAGE_TAG=agents-orchestration-runner:latest

if command -v docker >/dev/null 2>&1; then
  CONTAINER_ENGINE=docker
elif command -v podman >/dev/null 2>&1; then
  CONTAINER_ENGINE=podman
else
  echo "install docker or podman first" >&2
  exit 1
fi

"$CONTAINER_ENGINE" build --tag "$IMAGE_TAG" "$IMAGE_DIRECTORY"
echo "runner image: $IMAGE_TAG (built with $CONTAINER_ENGINE)"
