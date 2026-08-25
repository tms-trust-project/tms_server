#!/bin/bash
# ----------------------------------------------------------------
# Uninstall a docker-based install of TMS server.
# ----------------------------------------------------------------

PrgName=$(basename "$0")
# Determine absolute path to location from which we are running and change to that directory.
RUN_DIR=$(pwd)
PRG_RELPATH=$(dirname "$0")
cd "$PRG_RELPATH"/. || exit
PRG_PATH=$(pwd)

echo
echo "======================================================================================="
echo "======= WARNING ======= WARNING ======= WARNING ======= WARNING ======= WARNING ======="
echo "========================== THIS IS A DESTRUCTIVE OPERATION ============================"
echo "======================================================================================="
echo
read -p "WARNING DESTRUCTIVE UNINSTALL! Enter Y to continue: " resp
case $resp in
  [yY]* ) echo "Continuing ... " ;;
  *) echo "Uninstall cancelled. Exiting ... " ; exit 1 ;;
esac

# Kill containers that might be running
docker kill tms_sleep > /dev/null 2>&1
docker kill tms_server > /dev/null 2>&1

# Remove containers that might have exited and not been removed
docker rm tms_sleep > /dev/null 2>&1
docker rm tms_server

# Delete the docker volume
docker volume rm tms_server_vol

# Remove the tms-root directory
rm -fr "$HOME"/tms-docker/tms_local
