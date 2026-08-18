#!/bin/bash
# Cleanup install of ver 0.4.0
# Helpful for testing after failed local installs
#
# WARNING DESTRUCTIVE UNINSTALL
#
# Exit if a command returns status different from 0
set -o errexit
# An unset variable is an error (avoids silently continuing after a typo in a name)
set -o nounset
# If any of the components of a pipe fails, then the pipe fails
set -o pipefail

# Set env vars
. $HOME/tms_env/tms_env_local_install

# Reset DB
../deployment/postgres/tms_drop_db.sh
../deployment/postgres/tms_init_db.sh

# Clean up installed directories
rm -fr ~/.tms
if [ -d "/tmp/tms_server" ]; then
  rm -fr /tmp/tms_server/
fi
if [ -d "/opt/tms_server" ]; then
  rm -fr /opt/tms_server/
fi
