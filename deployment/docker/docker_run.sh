#!/usr/bin/env bash
#set -x

# This script should only be called AFTER docker_setup_tms.sh has successfully run.

# The tag of the image to be run needs to be the first and only parameter.
PrgName=$(basename "$0")
if [ $# -ne 1 ]; then 
    echo "Usage: $PrgName <docker tag>"
    echo "  where <docker tag> is the image version tag"
    echo "For example $PrgName dev"
    exit 1
fi
# Check that all required env variables are set
FAILED=false
#env_list="POSTGRES_PASSWORD TMS_DB_USER_PASSWORD"
env_list="TMS_DB_USER_PASSWORD"
for name in $env_list
do
  if [[ -z "${!name}" ]]; then
    echo "Please set env var ${name} before running this script"
    FAILED=true
  fi
done
if [ "$FAILED" = true ]; then
  echo "Please set required environment variables"
  echo "Exiting ..."
  exit 1
fi

# Assign the image tag
TAG=$1

# This script starts the tms_server in the background in a docker container under the user ID
# that launches it.  The host's ~/tms-docker/tms_customizations directory is mounted into the 
# container and the persistent named volume, tms_docker_vol, contains the .tms directory that 
# the server uses during execution.  The container is removed when the server exits.
set -xv
#docker run --name tms_server_container --user "$(id -u)":"$(id -g)" -e HOME=/tms-root -p 3001:3000 -d --rm \
docker run --name tms_server --user "$(id -u)":"$(id -g)" -e HOME=/tms-root -p 3001:3000 -d \
--volume tms_docker_vol:/tms-root \
--mount type=bind,source=${HOME}/tms-docker/tms_local,target=/tms-root/tms_local \
--volume="/etc/group:/etc/group:ro" \
--volume="/etc/passwd:/etc/passwd:ro" \
--volume="/etc/shadow:/etc/shadow:ro" \
tapis/tms_server:${TAG}