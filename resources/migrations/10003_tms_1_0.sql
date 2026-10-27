-- ================================================================================================
-- Alter schema for TMS Portal / TMS Credential Server backends. Both will use the same DB
--   Create new tables, update existing tables
-- ================================================================================================

-- ********************************************************************
-- *******   New Tables
-- ********************************************************************
-- ---------------------------------------
-- Identity_provider_types table
-- ---------------------------------------
CREATE TABLE IF NOT EXISTS identity_provider_types
(
    provider_type TEXT PRIMARY KEY  NOT NULL,
    created       TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated       TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc')
);
ALTER TABLE identity_provider_types OWNER TO tms;
--
-- Insert hard-coded types
--
-- TODO/TBD Might be able to create globus and tacc_tapis as part of a seeding step, but implicit_mode
--   should always be created here for migration from TMS 0.3.
INSERT INTO identity_provider_types (provider_type) VALUES ('globus');
INSERT INTO identity_provider_types (provider_type) VALUES ('tacc_tapis');
INSERT INTO identity_provider_types (provider_type) VALUES ('implicit_mode');

-- ---------------------------------------
-- Identity_providers table
-- ---------------------------------------
-- All cloud and resource IdPs
-- Example cloud IdPs: UT Austin, UC San Diego, Univ of Pittsburgh, ACCESS
-- Example resource providers: TACC, SDSC, PSC
CREATE TABLE IF NOT EXISTS identity_providers
(
    id                    TEXT              NOT NULL UNIQUE,
    name                  TEXT              NOT NULL,
    oauth2_client_id      TEXT              NOT NULL,
    oauth2_client_secret  TEXT              NOT NULL,
    identity_redirect_url TEXT              NOT NULL,
    oauth2_token_url      TEXT              NOT NULL,
    oauth2_jwks_url       TEXT,
    oauth2_public_key     TEXT,
    oidc_user_info_url    TEXT,
    resources_services_url TEXT,
    scope                 TEXT,
    provider_type         TEXT              NOT NULL REFERENCES identity_provider_types(provider_type) ON UPDATE CASCADE,
    supports_login        BOOLEAN           NOT NULL DEFAULT false,
    supports_resources    BOOLEAN           NOT NULL DEFAULT false,
    created               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc')
);
ALTER TABLE identity_providers OWNER TO tms;
--
-- Create an identity_provider to be used as resource provider for existing "implicit trust" mode records, i.e.
--    existing MVP legacy records.
-- Only TACC is running TMS server 0.3 and the RP is always strictly just TACC.
-- The TMS host module tms_keycmd is only running on TACC resources and the use of TMS is restricted to Tapis
--   tenants which use TACC ldap for authentication.
INSERT INTO identity_providers (id, name, oauth2_client_id, oauth2_client_secret, identity_redirect_url, oauth2_token_url,
                                provider_type, supports_login, supports_resources)
VALUES ('implicit_mode_tacc_rp', 'ImplictMode TACC Resource Provider', '12345678-1234-taccrp-implictmode',
        'ImplictModeZf9afuG9RzpE6DCDvkrM', 'https://auth.implicit.fake.org/v2/oauth2/authorize',
        'https://auth.implicit.fake.org/v2/oauth2/token', 'implicit_mode', false, false);
--
-- Create an identity_provider to be used as an IdP for existing MVP legacy "implicit trust" records.
-- Only TACC is running TMS server 0.3 and the IdP is always strictly just TACC.
-- The TMS host module tms_keycmd is only running on TACC resources and the use of TMS is restricted to Tapis
--   tenants which use TACC ldap for authentication.
INSERT INTO identity_providers (id, name, oauth2_client_id, oauth2_client_secret, identity_redirect_url, oauth2_token_url,
                                provider_type, supports_login, supports_resources)
VALUES ('implicit_mode_tacc_idp', 'ImplictMode TACC Identity Provider', '12345678-1234-taccidp-implicitmode',
        'ImplictModeZf9afuG9RzpE6DCDvkrM', 'https://auth.implicit.fake.org/v2/oauth2/authorize',
        'https://auth.implicit.fake.org/v2/oauth2/token', 'implicit_mode', false, false);
--
-- Create an identity_provider to be used as placeholder to be used when adding columns that are NOT NULL.
-- This should not be in place permanently, it should get replaced during an upgrade.
INSERT INTO identity_providers (id, name, oauth2_client_id, oauth2_client_secret, identity_redirect_url, oauth2_token_url,
                                provider_type, supports_login, supports_resources)
VALUES ('implicit_mode_unknown', 'ImplictMode Unkown RP', '12345678-1234-unknown-implicitmode',
        'ImplictModeUnknownZRzpE6DCDvkrM', '', '', 'implicit_mode', false, false);

-- ---------------------------------------
-- tms_identities table
-- ---------------------------------------
-- Whenever a user logs in and establishes their cloud identity through TMS we record it here.
-- Note that because this is not a record of their last login there is no updated column.
-- This is needed because for delegations we want to make sure we always reference a unique tms_identity.
-- If all tables reference this as a Foreign Key this will ensure that tms_identity columns all reference the same
--   unique identity unique within TMS
CREATE TABLE IF NOT EXISTS tms_identities
(
    seq_id SERIAL PRIMARY KEY,
    tms_identity TEXT   NOT NULL UNIQUE,
    enabled BOOLEAN NOT NULL DEFAULT true,
    created TIMESTAMPTZ NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc')
);
ALTER TABLE tms_identities OWNER TO tms;

-- TODO For existing MVP legacy "implicit trust" mode records created for TMS 0.3 and earlier, we need to
--      add TMS identities for every record in the user_mfa, delegations tables.
-- TODO Select all distinct client_user_id records from user_mfa and delegations and for each create a new
--   tms_identity record in tms_identities.
--

--  Create a TMS identity with a special name to act as a potential fallback for implicit trust mode records.
--   TODO: Needed for migration of existing MVP legacy records? Or not needed? Probably not, since we should create a
--         TMS identity for each user associated with legacy records?
INSERT INTO tms_identities (tms_identity) VALUES ('ImplicitUserUnknown@ImplictModeIdP');

-- ---------------------------------------
-- keys table
-- ---------------------------------------
-- TODO brief description
CREATE TABLE IF NOT EXISTS keys
(
    kid             TEXT PRIMARY KEY NOT NULL,
    jwt_public_key  TEXT             NOT NULL,
    jwt_private_key TEXT             NOT NULL,
    created         TIMESTAMPTZ      NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated         TIMESTAMPTZ      NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc')
);
ALTER TABLE keys OWNER TO tms;

-- ---------------------------------------
-- configuration table
-- ---------------------------------------
-- TODO brief description
CREATE TABLE IF NOT EXISTS configuration
(
    config_name  TEXT PRIMARY KEY NOT NULL,
    config_value JSONB            NOT NULL,
    created      TIMESTAMPTZ      NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated      TIMESTAMPTZ      NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc')
);
ALTER TABLE configuration OWNER TO tms;

-- ---------------------------------------
-- allowed_redirects table
-- ---------------------------------------
-- Allowable re-directs for each client
CREATE TABLE IF NOT EXISTS allowed_redirects
(
    seq_id SERIAL PRIMARY KEY,
    uri       TEXT        NOT NULL,
    client_id TEXT        NOT NULL,
    created   TIMESTAMPTZ NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated   TIMESTAMPTZ NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    constraint fk_client_id FOREIGN KEY (client_id) REFERENCES clients (client_id)
);
ALTER TABLE allowed_redirects OWNER TO tms;

-- ---------------------------------------
-- auth_code_data table
-- ---------------------------------------
CREATE TABLE IF NOT EXISTS auth_code_data
(
    auth_code       TEXT PRIMARY KEY NOT NULL,
    client_id       TEXT             NOT NULL,
    redirect_uri    TEXT             NOT NULL,
    idp_id          TEXT             NOT NULL,
    idp_type        TEXT             NOT NULL,
    claims          JSONB            NOT NULL,
    created         TIMESTAMPTZ      NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated         TIMESTAMPTZ      NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    FOREIGN KEY(client_id) REFERENCES clients(client_id)
);

-- ---------------------------------------
-- issued_tokens table
-- ---------------------------------------
CREATE TABLE IF NOT EXISTS issued_tokens
(
    access_token  TEXT PRIMARY KEY  NOT NULL,
    expiration    TIMESTAMPTZ       NOT NULL,
    revoked       BOOLEAN           NOT NULL DEFAULT false,
    created       TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated       TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc')
);

-- TODO Now that all columns are added for existing MVP legacy "implicit trust" records created for TMS 0.3 and earlier,
--  we probably need to fill in some attributes for various tables, attributes: tms_identity, rp_id, rp_account
--    and tms_identity for every record in the old user_mfa table and delegations table.

-- ----------------------------------------------------------------------
-- Resources available in a Resource Provider.
-- ----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS resources (
    id SERIAL PRIMARY KEY,
    resource_local_id TEXT NOT NULL, -- TODO what is resource_local_id?
    name TEXT NOT NULL,
    url TEXT NOT NULL,
    description TEXT,
    rp_id TEXT NOT NULL REFERENCES identity_providers (id),
    created TIMESTAMPTZ NOT NULL DEFAULT (NOW () AT TIME ZONE 'utc'),
    updated TIMESTAMPTZ NOT NULL DEFAULT (NOW () AT TIME ZONE 'utc'),
    UNIQUE (rp_id, resource_local_id)
);
ALTER TABLE resources OWNER TO tms;

-- ---------------------------------------
-- resource_host_accounts table
-- ---------------------------------------
-- This table establishes the host login user in a resource for a Resource Provider identity.
CREATE TABLE IF NOT EXISTS resource_host_accounts
(
   id SERIAL PRIMARY KEY,
-- TODO/TBD: I'm thinking reference to resource_provider_logins does not make sense. What if "user" has never logged into RP?
--           And maybe reference to resources also does not make sense? for similar reason? Needs more thought.
--           or maybe by the time we do an INSERT for this table the other two records must exist?
--           But de-normalizing by using rp_id and rp_account would probably help a human troubleshoot. Have both?
--           Plus, when we are looking up host_login_user when we are creating a key-pair (pubkeys_create.rs) what we
--               will have is rp_id and rp_account.
-- TODO        resource_id INTEGER REFERENCES resources (id),   -- TODO Is this what we are calling rp_id in the above?
   rp_id TEXT NOT NULL REFERENCES identity_providers (id), -- TODO Use this to replace above line?
   rp_account TEXT NOT NULL,  -- REFERENCES ???? (id),
-- TODO NOTE: for rp_account there is no table to reference. Would it make sense for this record to be what other tables reference?
--        rp_account is in tables resource_provider_logins, delegations, pubkeys, reservations
-- TODO        resource_provider_login_id INTEGER REFERENCES resource_provider_logins (id), -- TODO rp_account instead?
   host_login_user TEXT NOT NULL,
   created TIMESTAMPTZ NOT NULL DEFAULT (NOW () AT TIME ZONE 'utc'),
   updated TIMESTAMPTZ NOT NULL DEFAULT (NOW () AT TIME ZONE 'utc')
-- TODO???        UNIQUE (rp_id, host_login_user)
--TODO        UNIQUE (resource_id, resource_provider_login_id)
);
ALTER TABLE resource_host_accounts OWNER TO tms;

-- ----------------------------------------------------------------------
-- client_implicit_mode_allowed_resources table
-- ----------------------------------------------------------------------
-- This table establishes the set of resources allowed for a tms app client which uses implicit_mode
CREATE TABLE IF NOT EXISTS client_allowed_resources
(
    id SERIAL PRIMARY KEY,
    client_id INTEGER NOT NULL REFERENCES clients (id),
    resource_id INTEGER REFERENCES resources (id),
    created TIMESTAMPTZ NOT NULL DEFAULT (NOW () AT TIME ZONE 'utc'),
    updated TIMESTAMPTZ NOT NULL DEFAULT (NOW () AT TIME ZONE 'utc'),
    UNIQUE (client_id, resource_id)
);
ALTER TABLE client_allowed_resources OWNER TO tms;


-- ********************************************************************
-- *******   Updates to Existing Tables
-- ********************************************************************

-- ---------------------------------------
-- clients table
-- ---------------------------------------
-- ================================================================================================
-- Rename columns in clients table to better match what TMS portal code is using.
-- Add columns tms_mode, rp_id
-- ================================================================================================
-- Rename column app_name in clients table to name. app_name stands for "application client" but that is not
-- the term used in many other related documents so it could be confusing. Also, this is what TMS portal uses.
ALTER TABLE clients RENAME COLUMN app_name TO name;
-- Rename column client_secret to secret. This is simpler and matches what the portal code is using.
-- NOTE: Keep column client_id as is because TMS server already has a column 'id' as a SERIAL primary key
ALTER TABLE clients RENAME COLUMN client_secret TO secret;
-- Add column tms_mode: ExplicitTrust, ImplicitTrust
ALTER TABLE clients ADD COLUMN IF NOT EXISTS tms_mode TEXT NOT NULL DEFAULT 'ExplicitTrust'
    CHECK (tms_mode IN ('ExplicitTrust', 'ImplicitTrust'));
-- Add column for rp to be used for the case of ImplicitTrust.
ALTER TABLE clients ADD COLUMN IF NOT EXISTS rp_id TEXT REFERENCES identity_providers(id);

-- ---------------------------------------------------------------
-- user_mfa table (now resource_provider_logins)
-- ---------------------------------------------------------------
-- ================================================================================================
-- Rename table user_mfa to resource_provider_logins to better reflect the purpose.
--   This table records the last time the user logged into their resource provider account.
-- ================================================================================================
ALTER TABLE IF EXISTS user_mfa RENAME TO resource_provider_logins;

-- Drop column expires_at. We will now use last_login instead for this.
-- Eventually we might have some type of policies table to support RPs specifying expiry for logins.
ALTER TABLE resource_provider_logins DROP COLUMN IF EXISTS expires_at;

-- Rename column tms_user_id to tms_identity for table resource_provider_logins.
ALTER TABLE resource_provider_logins RENAME COLUMN tms_user_id TO tms_identity;

-- ================================================================================================
-- Add columns and constraints to resource_provider_logins table
-- ================================================================================================
ALTER TABLE resource_provider_logins ADD COLUMN IF NOT EXISTS rp_id TEXT NOT NULL DEFAULT 'implicit_mode_unknown'
    REFERENCES identity_providers(id);
ALTER TABLE resource_provider_logins ADD COLUMN IF NOT EXISTS rp_account TEXT NOT NULL DEFAULT 'implicit_user_unknown';
ALTER TABLE resource_provider_logins ADD COLUMN IF NOT EXISTS last_login TIMESTAMPTZ NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc');
-- Save the access and refresh tokens from logging in to a resource provider.
-- They will be used for further interactions with the RP service.
ALTER TABLE resource_provider_logins ADD COLUMN IF NOT EXISTS rp_access_token TEXT;
ALTER TABLE resource_provider_logins ADD COLUMN IF NOT EXISTS rp_refresh_token TEXT;

ALTER TABLE resource_provider_logins ADD CONSTRAINT identity_id_account_key UNIQUE (tms_identity, rp_id, rp_account);
ALTER TABLE resource_provider_logins ADD CONSTRAINT fk_rp_id FOREIGN KEY (rp_id) REFERENCES identity_providers(id);
-- ------------------------------------------------------------------------------------------------
-- Add foreign keys for tms_identity referencing tms_identities table for tables resource_provider_logins
-- Each tms_identity in each table must represent an identity in the tms_identities table.
-- As also mentioned above, this is needed because we want to make sure we always reference a unique tms_identity.
-- If all tables reference this as a foreign key this will ensure that tms_identity columns all reference the same
-- unique identity unique within TMS
-- ------------------------------------------------------------------------------------------------
ALTER TABLE resource_provider_logins ADD CONSTRAINT fk_tms_identity
    FOREIGN KEY (tms_identity) REFERENCES tms_identities (tms_identity);

-- ------------------------------------------------------------------------------------------------
-- user_hosts table
-- ------------------------------------------------------------------------------------------------
-- We are dropping this table and removing associated code.
-- New tables are being introduced to track resources associated with a resource provider and host user logins
--   associated with resource provider accounts. See new tables resources and resource_host_accounts
-- First, drop constraints pointing to user_hosts.
ALTER TABLE pubkeys DROP CONSTRAINT IF EXISTS pubkeys_client_user_id_host_host_account_fkey;
-- Second, drop the table
DROP TABLE IF EXISTS user_hosts;

-- ---------------------------------------
-- delegations table
-- ---------------------------------------
-- TODO/TBD Also drop column expires_at as is being done for resource_provider_logins table?
-- TODO -- Drop column expires_at. No longer needed/relevant?
-- --TODO ???Eventually we might have some type of policies table to support RPs specifying expiry?
--    Or keep as is for now so it is easy/quick for tms-server to check validity of delegation.
--    Currently (for MVP) it is essentially forever. Can always drop it later.
--    Possibly will end up maintaining this by simply removing the delegation based on some policy
--    rather than having an expiry.
--
-- ALTER TABLE delegations DROP COLUMN IF EXISTS expires_at;

-- Notes on the "why" for some of these changes.
--   What is needed to authorize CRUD calls for this table? tms_identity, rp_id, rp_account
--     - since we must already trust the TMS client (i.e. Tapis client) we can allow the client to provide these.

-- Drop constraint delegations_client_user_id_fkey
-- Somehow it becomes:
--      delegations_client_user_id_fkey: FOREIGN KEY (rp_account) REFERENCES resource_provider_logins(tms_identity)
-- probably due to all the renaming above. Below we create the correct one for tms_identity when adding the column
ALTER TABLE delegations DROP CONSTRAINT IF EXISTS delegations_client_user_id_fkey;
--Add column tms_identity with foreign key reference to tms_identities
-- NOTE: The hard coded string here must match the one used above for the tms_identities table.
ALTER TABLE delegations ADD COLUMN IF NOT EXISTS tms_identity TEXT NOT NULL DEFAULT 'ImplicitUserUnknown@ImplictModeIdP'
    REFERENCES tms_identities(tms_identity) ON UPDATE CASCADE ON DELETE CASCADE;
-- TODO after above ADD COLUMN, do we need to modify the rp_account value for the existing legacy MVP implicit trust records?
--      e.g., if my TACC id is someuser, should we update it to be 'someuser_ImplictModeRP' or similar?
--      NOTE: Must create tms_identity also
--      See similar note below under pubkeys table
ALTER TABLE delegations RENAME COLUMN client_user_id TO rp_account;
ALTER TABLE delegations ADD COLUMN IF NOT EXISTS rp_id TEXT NOT NULL DEFAULT 'implicit_mode_unknown'
    REFERENCES identity_providers(id);
-- For delegations table (tms_identity, client_id, rp_id, rp_account) uniquely identify the record
CREATE UNIQUE INDEX IF NOT EXISTS delegations_tmsid_cltid_rpid_rpacct_idx ON delegations (tms_identity, client_id, rp_id, rp_account);

-- ---------------------------------------
-- pubkeys table
-- ---------------------------------------
-- Note on authz for CRUD calls: we must already trust the TMS app client so OK to allow the client to provide these.
-- Notes on the "why" for some of these changes.
--   create keypair - will need tms_identity, rp_id and rp_login so we can check the delegation record.
--                  - also will have host_login_user to record the host account provided by the RP
--   get pubkey - just need pubkey_fingerprint
ALTER TABLE pubkeys RENAME COLUMN client_user_id TO rp_account;
-- TODO after above rename, do we need to modify the rp_account value for the existing legacy MVP implicit trust records?
--      e.g., if my TACC id is someuser, should we update it to be 'someuser_ImplictModeRP' or similar?
--      NOTE: Must create tms_identity also
--      See similar note above under delegations table.
ALTER TABLE pubkeys ADD COLUMN IF NOT EXISTS tms_identity TEXT NOT NULL DEFAULT 'ImplicitUserUnknown@ImplictModeIdP'
    REFERENCES tms_identities(tms_identity);
-- For the legacy MVP records, we can use the implicit trust TACC RP here.
ALTER TABLE pubkeys ADD COLUMN IF NOT EXISTS rp_id TEXT NOT NULL DEFAULT 'implicit_mode_tacc_rp'
    REFERENCES identity_providers(id);
-- Rename column host_account to host_login_user. We are removing host_account from pubkeys create request.
-- We will look up host_login_user (as provided by RP) at the time of key-pair creation.
ALTER TABLE pubkeys RENAME COLUMN host_account TO host_login_user;

-- Fix up constraints. After alterations above there are problems
--   After renaming we end up with pubkeys_client_user_id_fkey as FOREIGN KEY (rp_account)
--       REFERENCES resource_provider_logins(tms_identity)
ALTER TABLE pubkeys DROP CONSTRAINT IF EXISTS pubkeys_client_user_id_fkey;

-- ---------------------------------------
-- reservations table
-- ---------------------------------------
ALTER TABLE reservations RENAME COLUMN client_user_id TO rp_account;
ALTER TABLE reservations ADD COLUMN IF NOT EXISTS rp_id TEXT NOT NULL DEFAULT 'implicit_mode_unknown'
    REFERENCES identity_providers(id);
