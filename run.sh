#!/bin/sh
#
# Forked from https://github.com/linuxserver/docker-docker-compose/blob/master/run.sh
#
# Run docker-compose in a container
#
# This script will attempt to mirror the host paths by using volumes for the
# following paths:
#   * $(pwd)
#   * $(dirname $COMPOSE_FILE) if it's set
#   * $HOME if it's set
#
# You can add additional volumes (or any docker run options) using
# the $COMPOSE_OPTIONS environment variable.
#
# You can set a specific image tag from Docker Hub, such as "1.26.2-ls9", or "alpine"
# using the $DOCKER_COMPOSE_IMAGE_TAG environment variable (defaults to "latest")
#


set -e

# set image tag to latest if not globally set
DOCKER_COMPOSE_IMAGE_TAG="${DOCKER_COMPOSE_IMAGE_TAG:-latest}"
IMAGE="ghcr.io/linuxserver/docker-compose:v2-2.16.0-r1-ls65@sha256:b90af555611ed2364358fa98aadeee15856abd57709d06539f33629108055f61"

# Setup options for connecting to docker host
if [ -z "$DOCKER_HOST" ]; then
    DOCKER_HOST='unix:///var/run/docker.sock'
fi
if [ -S "${DOCKER_HOST#unix://}" ]; then
    DOCKER_ADDR="-v ${DOCKER_HOST#unix://}:${DOCKER_HOST#unix://} -e DOCKER_HOST"
else
    DOCKER_ADDR="-e DOCKER_HOST -e DOCKER_TLS_VERIFY -e DOCKER_CERT_PATH"
fi


# Setup volume mounts for compose config and context
if [ "$(pwd)" != '/' ]; then
    VOLUMES="-v $(pwd):$(pwd)"
fi
if [ -n "$COMPOSE_FILE" ]; then
    COMPOSE_OPTIONS="$COMPOSE_OPTIONS -e COMPOSE_FILE=$COMPOSE_FILE"
    compose_dir="$(dirname "$COMPOSE_FILE")"
    # canonicalize dir, do not use realpath or readlink -f
    # since they are not available in some systems (e.g. macOS).
    compose_dir="$(cd "$compose_dir" && pwd)"
fi
if [ -n "$COMPOSE_PROJECT_NAME" ]; then
    COMPOSE_OPTIONS="-e COMPOSE_PROJECT_NAME $COMPOSE_OPTIONS"
fi
# TODO: also check --file argument
if [ -n "$compose_dir" ]; then
    VOLUMES="$VOLUMES -v $compose_dir:$compose_dir"
fi
if [ -n "$HOME" ]; then
    VOLUMES="$VOLUMES -v $HOME:$HOME -e HOME" # Pass in HOME to share docker.config and allow ~/-relative paths to work.
fi

# Always set -i to support piped and terminal input in run/exec
DOCKER_RUN_OPTIONS="$DOCKER_RUN_OPTIONS -i"


# Handle userns security
if docker info --format '{{json .SecurityOptions}}' 2>/dev/null | grep -q 'name=userns'; then
    DOCKER_RUN_OPTIONS="$DOCKER_RUN_OPTIONS --userns=host"
fi

# Detect SELinux and add --privileged if necessary
if docker info --format '{{json .SecurityOptions}}' 2>/dev/null | grep -q 'name=selinux'; then
    DOCKER_RUN_OPTIONS="$DOCKER_RUN_OPTIONS --privileged"
fi

# shellcheck disable=SC2086
exec docker run --rm $DOCKER_RUN_OPTIONS $DOCKER_ADDR $COMPOSE_OPTIONS $VOLUMES -w "$(pwd)" $IMAGE "$@"
