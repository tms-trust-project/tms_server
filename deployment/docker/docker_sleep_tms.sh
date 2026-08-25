#!/usr/bin/env bash

# Run TMS image with a long sleep so we can examine how it looks inside the running container.

# The tag of the image to be run needs to be the first and only parameter.
PrgName=$(basename "$0")
if [ $# -ne 1 ]; then 
    echo "Usage: $PrgName <docker tag>"
    echo "  where <docker tag> is the image version tag"
    echo "E.g. $PrgName dev"
    exit 1
fi

# Assign the image tag
TAG=$1

docker run --name tms_sleep --user "$(id -u)":"$(id -g)" -e HOME=/tms-root -d --rm \
--volume tms_docker_vol:/tms-root \
--mount type=bind,source=${HOME}/tms-docker/tms_local,target=/tms-root/tms_local \
--volume="/etc/group:/etc/group:ro" \
--volume="/etc/passwd:/etc/passwd:ro" \
--volume="/etc/shadow:/etc/shadow:ro" \
tapis/tms_server:${TAG} \
/bin/bash -c "sleep 10000"
