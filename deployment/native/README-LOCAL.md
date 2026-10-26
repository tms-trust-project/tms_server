# Locally Installing and Testing TMS Credential Server (TMSCS) version 0.4

## Overview
This document describes how to set up and natively install TMS Credential Server (TMSCS) for local testing. Please note
that a local installation of TMS uses the directories `$HOME/tms`, `$HOME/tms_server` and `$HOME/tms_local`.

## One-Time Installation Prerequisite Procedures
Perform the following one-time installation steps prior to installing TMSCS for the first time.

### Install PostgreSQL
This may be installed and running almost anywhere. The simplest option is to install locally as a docker deployment.
Please see files under the directory `deployment/postgres` for an example docker compose file and scripts that may
be used to deploy a local postgres server. In order to use the scripts in this repo you will need to have the
postgres admin user as `postgres` and save the admin password for later use when initializing the DB for TMSCS.

### Install rust and clone the repository
For example:
```
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
mkdir $HOME/src
cd $HOME/src
git clone https://github.com/tapis-project/tms_server.git
```

## Environment variables used during installation

### Required
The following environment variables are required when installing TMSCS:
- POSTGRES_PASSWORD
  - Password for the postgres admin user `postgres`
- TMS_DB_USER_PASSWORD
  - Password for the TMS DB user
- TMS_SSL_CERT_PATH
  - Path to the SSL full-chain certificate file in PEM format that is loaded at startup.
  - Example: $HOME/src/tms_server/resources/certs_self/cert.pem
- TMS_SSL_KEY_PATH
  - Path to the private key file in PEM format associated with the server SSL certificate.
  - Example: $HOME/src/tms_server/resources/certs_self/key.pem

### Optional
Other env variables that can be set to override defaults:
- TMS_DB_HOST
  - Host server running PostgreSQL. default = localhost
- TMS_DB_PORT
  - Port at which PostgreSQL server is running. default = 5432

## Installing TMSCS
Once the prerequisite steps are taken and the required and optional environment variables are set, simply run the
installation script:
```
cd $HOME/src/tms_server/deployment/native
./local_install.sh
```

You will be prompted to review and accept the detected settings before continuing. Once installation is complete and
the server has been started manually the setup output information may be found in file `$HOME/tms/tms-setup.out`.

**WARNING This output file contains the administrator credentials.**

**WARNING This is only place where these credentials are displayed. Losing this information prevents administrative
actions and will likely make reinstallation necessary.**

The installation script will:
- Build TMSCS from source files.
- Create the directories `$HOME/tms`, `$HOME/tms_server` and `$HOME/tms_local`.
- Install the server under `$HOME/tms` and `$HOME/tms_server`
- Copy the SSL certificate files into place at `$HOME/tms/certs`.
# TODO - Copy any custom `tms.toml` and `log4rs.yml` files from `$HOME/tms_local` to `$HOME/tms/config`.

## Running TMSCS
Note that the installation script will not start the service after installing. The server may be started up in the
foreground by running:
```
./local_start.sh
```
Or by using cargo. For example:
```
cd $HOME/src/tms_server
cargo run
```

The server should now be available on the localhost at port `8080` or whatever port was configured in a custom
`tms.toml` file that was located under `$HOME/tms_local`.
For example, to fetch the current TMS Server version:
```
curl -k https://localhost:3000/v1/tms/version
```

## Logging
The log configuration and formatting for `tms_server` is specified in the configuration file
`$HOME/tms/config/log4rs.yml`. By default, the log level is set to `INFO` and log messages are written to the file
`$HOME/tms/logs/tms_roller.log`.

## TMSCS Directories and Files

In this section we list the directories and files that are part of a TMSCS installation.

Installation Directories:
```
$HOME/tms
$HOME/tms_server
$HOME/tms_local
```

Under `$HOME/tms`
1. File *tms-db-env* - PostgreSQL DB settings. Used by backup script.
2. Directory **certs/** - Files:
     * *cert.pem* - Full-chain SSL certificate. Loaded at startup. In PEM format.
     * *key.pem* - Private key associated with the SSL certificate. In PEM format.
3. Directory **config** - Files:
    * *tms.toml* - The tms_server parameter file, which specifies the runtime options with which TMSCS executes.
    * *log4rs.yml* - The log configuration and formatting for tms_server.
4. Directory **logs** - Default location of log files as configured in *log4rs.yml*.
5. Directory **migrations** - Files defining the DB schema.

Under `$HOME/tms_server`
1. Directory **resources_src** - Initial resource files used during first-time server startup. 
2. File *tms_server* - Binary executable for server
3. File *tms.version* - 

Under `$HOME/tms_local`
1. File *tms.toml* - (Optional) Local customizations of TMSCS configuration settings.
2. File *log4rs.toml* - (Optional) Local customizations of TMSCS log settings.
3.File *tms-setup.out* - Output generated during first-time server startup, including administrator credentials.
    * **WARNING This is only place where these credentials are displayed. Losing them will likely make reinstallation necessary.**

Under `$HOME/backups`
1. Directory **scripts/** - Files:
    * *backup_tms_server.sh* - Script to back up TMSCS DB. Typically run as a cron job. Please see *backup/README.md*.
2. Directory **tms/** - Directory containing compressed backup files.
