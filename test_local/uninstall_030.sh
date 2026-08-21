#!/bin/bash
# Cleanup install of ver 0.3.0
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
echo
echo "WARNING!!!"
echo "WARNING!!! - This is a DESTRUCTIVE uninstall"
echo "WARNING!!!"
read -p "Enter Y to continue: " resp
case $resp in
  Y ) echo "Continuing ... " ;;
  *) echo "Uninstall cancelled. Exiting ... " ; exit 1 ;;
esac

set -xv
# Set env vars
. $HOME/tms_env/tms_env_local_install_030

# Reset DB
../deployment/postgres/tms_drop_db.sh
../deployment/postgres/tms_init_db.sh

rm -fr ~/.tms
if [ -d "/tmp/tms_server" ]; then
  rm -fr /tmp/tms_server/
fi
if [ -d "/opt/tms_server" ]; then
  rm -fr /opt/tms_server/
fi
# Clean up files created during install that cause errors when re-installing
/bin/rm -f $TMS_LOCAL_DIR/tms-db-env
/bin/rm -f $TMS_LOCAL_DIR/tms-install.out
/bin/rm -f $TMS_LOCAL_DIR/tms_service.env
