#!/bin/bash
#
# Re-init the DB and remove anything that might be left over from a previous native local install.
# Determine absolute path to location from which we are running and change to that directory.
RUN_DIR=$(pwd)
PRG_RELPATH=$(dirname "$0")
cd "$PRG_RELPATH"/. || exit
PRG_PATH=$(pwd)

$PRG_PATH/../deployment/postgres/tms_drop_db.sh
$PRG_PATH/../deployment/postgres/tms_init_db.sh
rm -fr $HOME/tms/*
rm -fr $HOME/tms_local/*
rmdir $HOME/tms
rmdir $HOME/tms_local

