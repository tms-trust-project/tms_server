#!/bin/bash
# Start the TMS server in the foreground after running local_install.sh

PrgName=$(basename "$0")

# An unset variable is an error (avoids silently continuing after a typo in a name)
set -o nounset
# If any of the components of a pipe fails, then the pipe fails
set -o pipefail

# Determine absolute path to location from which we are running and change to that directory.
RUN_DIR=$(pwd)
PRG_RELPATH=$(dirname "$0")
cd "$PRG_RELPATH"/. || exit
PRG_PATH=$(pwd)

# Make sure we are not running as root
if [ "$EUID" == 0 ]; then
  echo "This program must NOT be run as the root user"
  echo "Exiting ..."
  usage
fi

# Check that all required env variables are set
FAILED=false
env_list="POSTGRES_PASSWORD TMS_DB_USER_PASSWORD"
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

# Execute the server binary
cd $HOME
./tms_server/tms_server

# Switch back to current working directory of invoking user
cd "$RUN_DIR"
