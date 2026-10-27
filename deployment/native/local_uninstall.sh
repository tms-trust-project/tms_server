#!/bin/bash
# Uninstall script for a local install of TMS Server 0.4
#  - remove all installed files except the local directory
#  - reset the DB leaving only the tms user.
#
# WARNING: This is destructive
# WARNING: Make sure to stop the TMS Server first
#
# Assumptions:
#  - We are running from a checkout of tms_server github repo.
#
# Configuration:
#  - Following env variables are set at minimum:
#    - POSTGRES_PASSWORD
#  - Other env variables that can be set to override defaults:
#    - TMS_DB_HOST    default = localhost
#    - TMS_DB_PORT    default = 5432

PrgName=$(basename "$0")

# If any of the components of a pipe fails, then the pipe fails
set -o pipefail

# Determine absolute path to location from which we are running and change to that directory.
RUN_DIR=$(pwd)
PRG_RELPATH=$(dirname "$0")
cd "$PRG_RELPATH"/. || exit
PRG_PATH=$(pwd)

# This script is located under deployment/native. Some operations are relative to the top level source directory.
SRC_DIR=$PRG_PATH/../..

# Make sure we are not running as root
if [ "$EUID" == 0 ]; then
  echo "This program must NOT be run as the root user"
  echo "Exiting ..."
  usage
fi

# Check that all required env variables are set
FAILED=false
env_list="POSTGRES_PASSWORD"
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

# Set TMS root directory. Location of config, logs, etc.
ROOT_DIR="$HOME/tms"
# Set TMS server directory. Location of executable and initial resource files.
SERVER_DIR="$HOME/tms_server"
# Set local directory. Location of install output and optional custom tms.toml, log4rs.yml files.
LOCAL_DIR="$HOME/tms_local"

# Make sure psql is installed.
psql --version
RET_CODE=$?
if [ $RET_CODE -ne 0 ]; then
    echo "ERROR: Unable to access psql. Install the latest stable version of postgresql-client."
    echo "Exiting ..."
    exit $RET_CODE
fi

# Determine new version
VERS_NEW=$(cd $SRC_DIR; cargo pkgid | cut -d "#" -f2)
RET_CODE=$?
if [ $RET_CODE -ne 0 ]; then
  echo "Error determining new TMS version"
  echo "Exiting ..."
  exit $RET_CODE
fi

# Fill in some defaults needed by DB reset
TMS_DB_HOST="${TMS_DB_HOST:-localhost}"
TMS_DB_PORT="${TMS_DB_PORT:-5432}"

# Output configuration
echo "======================================================================================="
echo "======= WARNING ======= WARNING ======= WARNING ======= WARNING ======= WARNING ======="
echo "========================== THIS IS A DESTRUCTIVE OPERATION ============================"
echo "======================================================================================="
echo "******* UnInstall Settings ************************"
echo "******* TMS Version: $VERS_NEW ********************************"
echo "   ROOT_DIR=$ROOT_DIR"
echo "   SERVER_DIR=$SERVER_DIR"
echo "   LOCAL_DIR=$LOCAL_DIR"
echo "   TMS_DB_HOST=$TMS_DB_HOST"
echo "   TMS_DB_PORT=$TMS_DB_PORT"
echo "***********************************************************"
echo "****************************************************************************************************************"
echo "WARNING DESTRUCTIVE UNINSTALL! Many directories under $HOME/tms and $HOME/tms_server will be removed."
echo "****************************************************************************************************************"
read -p "Please review above settings. If they are correct enter Y to continue: " resp
echo
case $resp in
  [yY]* ) echo "Continuing ... " ;;
  *) echo "UnInstall cancelled. Exiting ... " ; exit 1 ;;
esac

# =====================================================================================
#  Perform uninstall
# =====================================================================================

# Cleanup installed directories and files
rm -fr $HOME/tms $HOME/tms_server $HOME/tms_local/tms-setup.out

# ============================================================================================
#  Drop the DB (idempotent)
# ============================================================================================
$SRC_DIR/deployment/postgres/tms_drop_db.sh

# Switch back to current working directory of invoking user
cd "$RUN_DIR"
