#!/bin/bash
# Build + install script for TMS Server 0.4
#  - No upgrade support. Can be used for local testing.
#
# Build and install the latest native version TMS Server
#
# This script builds a debug version and installs files under $HOME/tms, $HOME/tms_server and $HOME/tms_backups
# Local directory $HOME/tms_local will contain frist-time server startup output in tms-setup.out
#   as well as custom tms.toml and log4rs.yml files.
# The DB is initialized
#
# NOTE: Still could support custom tms.toml, log4rs.yml during install, but since directories and files are initialized
#       during first-time startup it seems we would have to add back support for the --install option for tms_server.
#
# Assumptions:
#  - We are running from a checkout of tms_server github repo.
#  - Following are installed: rust tool chain (cargo, rustc), postgres psql.
#
# Configuration:
#  - Following env variables are set at minimum:
#    - POSTGRES_PASSWORD
#    - TMS_DB_USER_PASSWORD
#  - Other env variables that can be set to override defaults:
#    - TMS_DB_HOST    default = localhost
#    - TMS_DB_PORT    default = 5432
#  - For a clean install the ssl cert variables must also be set
#    - TMS_SSL_CERT_PATH    : Path to the SSL full chain certificate file in PEM format.
#    - TMS_SSL_KEY_PATH     : Path to the private key file in PEM format associated with the SSL certificate.

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
env_list="POSTGRES_PASSWORD TMS_DB_USER_PASSWORD TMS_SSL_CERT_PATH TMS_SSL_KEY_PATH"
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
# Set backup directory
BAK_DIR="$HOME/tms_backups"
DB_ENV_FILE="tms-db-env"
DB_ENV_PATH="$LOCAL_DIR/${DB_ENV_FILE}"

# Make sure rust and psql are installed.
rustc --version
RET_CODE=$?
if [ $RET_CODE -ne 0 ]; then
    echo "ERROR: Unable to access rustc. Install the latest stable version of Rust."
    echo "Exiting ..."
    exit $RET_CODE
fi
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

# Set paths to source and destination of tms_server executable
EXEC_FILE_SRC=$SRC_DIR/target/debug/tms_server
EXEC_FILE_DST=$SERVER_DIR/tms_server

# Fill in some defaults needed by backup and DB migration
TMS_DB_HOST="${TMS_DB_HOST:-localhost}"
TMS_DB_PORT="${TMS_DB_PORT:-5432}"

# Set location of version file for installed version
VERS_FILE=$SERVER_DIR/tms.version

BAK_FILE="backup_tms_server.sh"
BAK_FILE_PATH="$BAK_DIR/scripts/$BAK_FILE"
# Timestamp to use when backing up existing files
BAK_TIMESTAMP=$(date  +%Y%m%d%H%M%S)

# Make sure the SSL cert files are at the specified paths.
RET_CODE=0
if [ ! -r "$TMS_SSL_CERT_PATH" ]; then
  echo "ERROR: SSL cert file not found at specified path: $TMS_SSL_CERT_PATH"
  RET_CODE=1
fi
if [ ! -r "$TMS_SSL_KEY_PATH" ]; then
  echo "ERROR: SSL key file not found at specified path: $TMS_SSL_KEY_PATH"
  RET_CODE=1
fi
if [ $RET_CODE -ne 0 ]; then
    echo "Exiting ..."
    exit $RET_CODE
fi

# Output configuration
echo "******* Install Settings ************************"
echo "******* TMS Version: $VERS_NEW ********************************"
echo "   ROOT_DIR=$ROOT_DIR"
echo "   SERVER_DIR=$SERVER_DIR"
echo "   LOCAL_DIR=$LOCAL_DIR"
echo "   BAK_FILE_PATH=$BAK_FILE_PATH"
echo "   TMS_DB_HOST=$TMS_DB_HOST"
echo "   TMS_DB_PORT=$TMS_DB_TMS_DB_PORT"
echo "   VERS_FILE=$VERS_FILE"
echo "   TMS_SSL_CERT_PATH=$TMS_SSL_CERT_PATH"
echo "   TMS_SSL_KEY_PATH=$TMS_SSL_KEY_PATH"
echo "***********************************************************"
echo
read -p "Please review above settings. If they are correct enter Y to continue: " resp
case $resp in
  [yY]* ) echo "Continuing ... " ;;
  *) echo "Install cancelled. Exiting ... " ; exit 1 ;;
esac

# =====================================================================================
#  Perform install/upgrade specific checks related to previous install
#  Do this before we start the potentially time-consuming build process
# =====================================================================================
# This is an install, there should not be an existing installation
if [ -e "$ROOT_DIR/config" ]; then
  echo "ERROR: TMS Server appears to already be installed under root directory: $ROOT_DIR. Path found: $ROOT_DIR/config"
  echo "Exiting ..."
  exit 1
fi
# There should not be an executable in the install dir.
if [ -e  "$EXEC_FILE_DST" ]; then
  echo "ERROR: Found existing tms_server executable at path: $EXEC_FILE_DST"
  echo "Exiting ..."
  exit 1
fi

# ============================================================================================
#  Initialize the DB (idempotent)
# ============================================================================================
$SRC_DIR/deployment/postgres/tms_init_db.sh

# ============================================================================================
#  Create directories that might not exist yet.
#  NOTE: We could get fancy and put these in a list, process in a loop and check exit code
# ============================================================================================
mkdir -p $SERVER_DIR
mkdir -p $LOCAL_DIR
mkdir -p $BAK_DIR/scripts
# Copy initial resources directory to server directory. This is used during initial server startup.
cp -pr $SRC_DIR/resources $SERVER_DIR/resources_src

# Construct script to be used by install user to build new executable
echo
echo "===== Creating script for building new executable"
echo "========================================================================================="
TMP_FILE=$(mktemp)
# Construct first part of script
echo "#!/bin/bash" > $TMP_FILE
# Place various env variables into script
echo "SRC_DIR=$SRC_DIR" >> $TMP_FILE
echo "SERVER_DIR=$SERVER_DIR" >> $TMP_FILE
echo "VERS_NEW=$VERS_NEW" >> $TMP_FILE

# Construct second part of script
cat >> $TMP_FILE << EOB
echo "Building TMS Server version $VERS_NEW"
echo "Server install directory: $SERVER_DIR"

# Build executable
echo "Building executable from directory: $SRC_DIR"
cd $SRC_DIR
cargo build > $SRC_DIR/cargo_build.log 2>&1
EOB

# Let the install user run the tmp script
chmod 755 $TMP_FILE

# Remove any existing executable
rm -f $EXEC_FILE_SRC
# Run the script to build the new executable
echo
echo "===== Running build script from file: $TMP_FILE"
echo "========================================================================================="
chmod +x $TMP_FILE
$TMP_FILE
RET_CODE=$?
echo "========================================================================================="
if [ $RET_CODE -ne 0 ]; then
  echo
  echo "*************** Error running build script"
  echo "*************** Please check file cargo_build.log"
  echo "Exiting ..."
  exit $RET_CODE
fi

# Make sure executable was built
if [ ! -f "$EXEC_FILE_SRC" ]; then
  echo "There appears to have been a problem building a new executable. File not found at path: $EXEC_FILE_SRC"
  echo "Please check for build errors"
  echo "Exiting ..."
  exit 1
fi

# Copy new tms_server executable into place
cp $EXEC_FILE_SRC $EXEC_FILE_DST
chmod 770 $EXEC_FILE_DST

# Copy latest backup script into place.
echo
echo "===== Updating backup script. Target path: $BAK_FILE_PATH"
echo "========================================================================================="
# If backup script currently exists then if necessary back it up
if [ -f "$BAK_FILE_PATH" ]; then
  # First check to see if we need to back it up.
  diff -q "${SRC_DIR}/backup/$BAK_FILE" "$BAK_FILE_PATH" 1>/dev/null
  RET_CODE=$?
  if [ $RET_CODE -ne 0 ]; then
    echo "Found existing backup script. Moving file: ${BAK_FILE_PATH} to file: ${BAK_FILE_PATH}.bak_${BAK_TIMESTAMP}"
    mv "$BAK_FILE_PATH" "${BAK_FILE_PATH}.bak_${BAK_TIMESTAMP}"
  fi
fi
cp -p "${SRC_DIR}/backup/$BAK_FILE" "$BAK_FILE_PATH"
chmod +x "$BAK_FILE_PATH"

# =====================================================================================
#  BEGIN install
# =====================================================================================

#####################################################
################## INSTALL ##########################
#####################################################
# --------------------------------------
# Clean install specific steps
# --------------------------------------
# Create environment file for backup script
echo
echo "===== Creating environment file for backup script. File path: $DB_ENV_PATH"
echo "========================================================================================="
# Construct env file
cat >> $DB_ENV_PATH << EOB
PG_DEPLOYMENT="tms-postgres"
PG_USER="tms"
PG_DBNAME="tmsdb"
PG_HOST="$TMS_DB_HOST"
PG_PORT="$TMS_DB_PORT"
PG_PASSWORD="$TMS_DB_USER_PASSWORD"
EOB
chmod 400 "$DB_ENV_PATH"

# If no example cert related files exist then copy example cert and key path files into local directory.
if [ ! -f $LOCAL_DIR/cert.path ]; then
  cp -p $SRC_DIR/deployment/native/cert.path $LOCAL_DIR/cert.path
fi
if [ ! -f $LOCAL_DIR/key.path ]; then
  cp -p $SRC_DIR/deployment/native/key.path $LOCAL_DIR/key.path
fi
# =====================================================================================
#  END install/upgrade specific code
# =====================================================================================

# Update version in install dir
echo "$VERS_NEW" > $VERS_FILE

echo
echo "===== To start the TMS server in the foreground, please run:"
echo "  $PRG_PATH/local_start.sh"
echo "========================================================================================="


# Remove the temporary file
rm -f $TMP_FILE
# Switch back to current working directory of invoking user
cd "$RUN_DIR"
