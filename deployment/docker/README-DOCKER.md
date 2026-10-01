# TMS Web Server Deployment

This directory (*tms_server/deployment/docker*) contains files related to the deployment of TMS server using a docker
image. This includes Dockerfiles, scripts and a docker-compose file.

## Environment Variables
Please note that for the setup, run and uninstall scripts some environment variables are required and others may be
used for a non-default postgres configuration:
- POSTGRES_PASSWORD (required for uninstall)
- TMS_DB_USER_PASSWORD (required)
- TMS_DB_HOST (optional)
- TMS_DB_PORT (optional)

## Building the Docker Image
The following scripts can be used to build and push *tms_server* images:
- `./docker_build.sh <image tag>`
- `./docker_push.sh <image tag>`

For example:
```
./docker_build.sh dev
./docker_push.sh dev
```

## Running the TMS Server

When starting TMS, one environment variable is required and others may be used for a non-default postgres configuration.
- TMS_DB_USER_PASSWORD (required)
- TMS_DB_HOST (optional)
- TMS_DB_PORT (optional)

The first time the server is run:
- A docker volume named `tms_server_vol` will be created.
- Directories will be created in the volume and resource files copied into place.
- A special administrative user will be created along with a random password.
- Test data will be created.
- A log of the administrator information and the test data will be written to a file in the volume:
-   `/home/tms/tms_local/tms-install.out`

The container will continue running after initialization.

## Customizing the TMS Server Prior to Initial Startup

The directory `/home/tms/tms_local` is used as a location for placing customized `tms.toml` and `log4rs.yml` files that
are used during the initial startup of TMS server. If these are present they will be copied to the `config` directory
under the root installation directory.

This directory is also used to write the output of the initial setup run. The `tms_server` writes the `tms-setup.out`
file to that directory. The file contains information about the default administrator user created during startup.

Once the server has been started for the first time the files under `home/tms/tms/config` can be modified.

### Customizing the TMS Runtime

The `/home/tms/tms/config` directory in the TMS server repository contains the two configuration files that can be
customized.

   - **tms.toml** - This file contains default values read by *tms_server* on start up.
   - **log4rs.yml** - This file contains the default logging configuration for *tms_server*.

Note that both files must have 600 permissions, which is the default.

## Running TMS Server

*tms_server* can be started using either `docker run` or `docker compose`. Each method is encapsulated in a script.

### Docker run 

Once TMS is installed and any customizations applied, run the following script to launch the TMS container in the
background:
```
./docker_run.sh` <image tag>
```

where `\<image tag\>` is the tag of the *tms_server* image to be run.

To view the logs:
```
docker logs tms_server
```

To stop the container (but not remove it), issue:
```
./docker_stop.sh
```

### Docker compose

Once TMS is installed and any customizations applied, run the following script to launch the TMS container in
the background:
```
./docker-compose_up.sh <image tag>
```

where `<image tag>` is the tag of the *tms_server* image to be run.

To stop and remove the container, issue:
```
./docker-compose_down.sh <image tag>
```

## Uninstalling TMS Server

>[!WARNING]
>WARNING - DESTRUCTIVE UNINSTALL!

If you want to wipe out and/or reinstall TMS from scratch, the script `docker_uninstall.sh` may be used.
This script should kill any running containers, remove any containers that have exited but not been removed and
remove the docker volume.

Two environment variables are required and others may be used for a non-default postgres configuration.
 - POSTGRES_PASSWORD (required)
 - TMS_DB_USER_PASSWORD (required)
 - TMS_DB_HOST (optional)
 - TMS_DB_PORT (optional)
