# TMS Server

A few files to support testing of the Trust Manager System (TMS) credential server

To run a quick smoke test against a locally running server deployed as a docker container.

First, set the env variables as approriate:
- POSTGRES_PASSWORD (required for uninstall)
- TMS_DB_USER_PASSWORD (required)
- TMS_DB_HOST (optional)
- TMS_DB_PORT (optional)

Then, from directory tms_server/deployment/docker:
1. Clean up:
   - ./docker_uninstall.sh
2. Build image: 
   - ./docker_build.sh dev
4. Run sleep (optional):
   - ./docker_sleep_tms.sh dev
4. Run server:
   - ./docker_run.sh dev
5. Check:
   - docker ps -a
6. Run smoke test from directory tms_server/test:
   - ./smoke_test.sh 

Starting up the long=running container `tms_sleep` allows you to examine the persistent volume at any time:
  - docker exec -it tms_sleep /bin/bash