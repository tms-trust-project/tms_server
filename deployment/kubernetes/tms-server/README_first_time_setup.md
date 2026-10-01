TMS Credential Server
=====================
First time deployment in kubernetes
-----------------------------------
1. Make sure the DB is up and available and you have the host, port and postgres user password information.
2. Generate a secure password for the TMS DB user.
3. Create a kubernetes secret named "tms-secrets" that contains the passwords using the names "postgres-password" and
   "postgres-tms-user-password". When bas64 encoding a secret before placing it an yml file be sure to use "echo -n".
4. If not using the default DB host and port then update the kubernetes environment variables to also set those
   as desired. See script "first-time-init-db-sh" for the default DB host and port.
5. Set up init data in $HOME/tms-portal/local
6. Run the script first_time_setup.sh. This script will:
    - Run first-time-init-db-sh as a kubernetes job.
    - Create a pvc.
    - Run first-time-setup-sh as a kubernetes job.
    - Deploy tms-server.
    - Set up ingress network access.
    - Seed initial config for tms-port if init file present: $HOME/tms-portal/local/init.sql
    - Seed test allowed_redirects if init file present: $HOME/tms-portal/local/init_test.sql
    - Re-deploy tms-portal deployment files present: $HOME/tms-portal/deployment

The service database role (i.e. user) and schema are initially created when the postgres database for the
TMS Server service is first deployed. The script containing SQL is run using a kubernetes job.

Each time the service starts up an sqlx migration is run to bring the DB schema up to date as needed.
This happens as part of application (main.rs) startup.
The calling sequence is:

```
   main.rs: static ref RUNTIME_CTX: RuntimeCtx = init_runtime_context() -> 
       config.rs:init_runtime_context() -> db_init.rs:init_db()
```

To completely remove TMS Credential Server and reset all data in the DB
-----------------------------------------------------------------------
Example commands:

```
mkdir src_github
cd src_github
git clone https://github.com/tms-trust-project/tms_server
cd tms_server/deployment/kubernetes/
./undeploy_destructive.sh
./first_time_setup.sh
kubectl logs --tail 1000 -f deploy/tms-server
```