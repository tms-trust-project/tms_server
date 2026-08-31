-- ================================================================================================
-- Alter schema for TMS Portal backend. TMS portal and server will use the same DB
-- ================================================================================================
-- ---------------------------------------
-- Identity Provider tables
-- ---------------------------------------
-- Identity provider types
CREATE TABLE IF NOT EXISTS identity_provider_types
(
    provider_type TEXT PRIMARY KEY            NOT NULL,
    created               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc')
);
ALTER TABLE identity_provider_types OWNER TO tms;
-- TODO include this as part of migration? or maybe move to a seeding step?
-- Insert hard-coded types
INSERT INTO identity_provider_types (provider_type)
VALUES ('globus');
INSERT INTO identity_provider_types (provider_type)
VALUES ('tacc_tapis');
INSERT INTO identity_provider_types (provider_type)
VALUES ('danger_mode');
INSERT INTO identity_provider_types (provider_type)
VALUES ('dummy_test');

-- All cloud and resource IdPs
-- Example cloud IdPs: UT Austin, UC San Diego, Univ of Pittsburgh, ACCESS
-- Example resource providers: TACC, SDSC, PSC
CREATE TABLE IF NOT EXISTS identity_providers
(
    uuid                  UUID PRIMARY KEY  NOT NULL DEFAULT gen_random_uuid(),
    id                    TEXT              NOT NULL UNIQUE,
    name                  TEXT              NOT NULL,
    client_id             TEXT              NOT NULL,
    client_secret         TEXT              NOT NULL,
    identity_redirect_url TEXT              NOT NULL,
    oauth2_token_url      TEXT              NOT NULL,
    oauth2_jwks_url       TEXT,
    oauth2_public_key     TEXT,
    oidc_user_info_url    TEXT,
    scope                 TEXT,
    provider_type         TEXT              NOT NULL,
    supports_login        BOOLEAN           NOT NULL DEFAULT false,
    supports_resources    BOOLEAN           NOT NULL DEFAULT false,
    created               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc')
);
ALTER TABLE identity_providers OWNER TO tms;
ALTER TABLE identity_providers
    ADD CONSTRAINT fk_provider FOREIGN KEY (provider_type) REFERENCES identity_provider_types (provider_type);

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
    tms_identity TEXT NOT NULL UNIQUE,
    created TIMESTAMPTZ NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc')
);
ALTER TABLE tms_identities OWNER TO tms;

-- TODO remove this insert
-- TODO 'dangerUser@dangerModeIdP'
--   temporary insert to accommodate test data. Also need related work done for upgrades.
--   If we end up always needing for test data we should have the tms_server startup create it.
INSERT INTO tms_identities (tms_identity) VALUES ('dangerUser@dangerModeIdP');

-- ---------------------------------------
-- keys table
-- ---------------------------------------
-- TODO brief description
CREATE TABLE IF NOT EXISTS keys
(
    kid             TEXT PRIMARY KEY            NOT NULL,
    jwt_public_key  TEXT                        NOT NULL,
    jwt_private_key TEXT                        NOT NULL,
    created               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc')
);
ALTER TABLE keys OWNER TO tms;

-- ---------------------------------------
-- configuration table
-- ---------------------------------------
-- TODO brief description
CREATE TABLE IF NOT EXISTS configuration
(
    config_name  TEXT PRIMARY KEY            NOT NULL,
    config_value JSONB                       NOT NULL,
    created               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc')
);
ALTER TABLE configuration OWNER TO tms;

-- ---------------------------------------
-- allowed_redirects table
-- ---------------------------------------
-- Allowable re-directs for each client
CREATE TABLE IF NOT EXISTS allowed_redirects
(
    uri       TEXT                        NOT NULL,
    client_id TEXT                        NOT NULL,
    created               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    constraint fk_client_id FOREIGN KEY (client_id) REFERENCES clients (client_id)
);
ALTER TABLE allowed_redirects OWNER TO tms;

CREATE TABLE IF NOT EXISTS auth_code_data
(
    auth_code       TEXT PRIMARY KEY            NOT NULL,
    client_id       TEXT                        NOT NULL,
    redirect_uri    TEXT                        NOT NULL,
    idp_id          TEXT                        NOT NULL,
    idp_type        TEXT                        NOT NULL,
    claims          JSONB                       NOT NULL,
    created               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    FOREIGN KEY(client_id) REFERENCES clients(client_id)
);

CREATE TABLE IF NOT EXISTS issued_tokens
(
    access_token  TEXT PRIMARY KEY  NOT NULL,
    expiration    TIMESTAMPTZ       NOT NULL,
    revoked       BOOLEAN           NOT NULL DEFAULT false,
    created       TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated       TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc')
);

-- ================================================================================================
-- Rename columns in clients table to better match what TMS portal code is using.
-- NOTE: No columns need to be added to table clients to accommodate TMS portal.
-- ================================================================================================
-- ------------------------------------------------------------------------------------------------
-- Rename column app_name in clients table to name. app_name stands for "application client" but that is not
-- the term used in many other related documents so it could be confusing. Also, this is what TMS portal uses.
-- ------------------------------------------------------------------------------------------------
ALTER TABLE clients RENAME COLUMN app_name TO name;
-- ------------------------------------------------------------------------------------------------
-- Rename column client_secret to secret. This is simpler and matches what the portal code is using.
-- NOTE: Keep column client_id as is because TMS server already has a column 'id' as a SERIAL primary key
-- ------------------------------------------------------------------------------------------------
ALTER TABLE clients RENAME COLUMN client_secret TO secret;

-- ================================================================================================
-- Rename table user_mfa to resource_provider_logins to better reflect the purpose.
--   This table records the last time the user logged into their resource provider account.
-- ================================================================================================
ALTER TABLE IF EXISTS user_mfa RENAME TO resource_provider_logins;

-- ------------------------------------------------------------------------------------------------
-- Rename column tms_user_id to tms_identity for table resource_provider_logins.
-- ------------------------------------------------------------------------------------------------
ALTER TABLE resource_provider_logins RENAME COLUMN tms_user_id TO tms_identity;

-- ================================================================================================
-- Add columns and constraints to resource_provider_logins table
-- ================================================================================================
ALTER TABLE resource_provider_logins ADD COLUMN IF NOT EXISTS rp_account TEXT NOT NULL DEFAULT '';
ALTER TABLE resource_provider_logins ADD COLUMN IF NOT EXISTS rp_uuid UUID NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE resource_provider_logins ADD COLUMN IF NOT EXISTS last_login TIMESTAMPTZ NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc');

ALTER TABLE resource_provider_logins ADD CONSTRAINT identity_uuid_account_key
    UNIQUE (tms_identity, rp_uuid, rp_account);
ALTER TABLE resource_provider_logins ADD CONSTRAINT uuid_fkey FOREIGN KEY (rp_uuid) REFERENCES identity_providers(uuid);

-- ------------------------------------------------------------------------------------------------
-- Add foreign key for tms_identity referencing tms_identities table
-- ------------------------------------------------------------------------------------------------
ALTER TABLE resource_provider_logins ADD CONSTRAINT fk_tms_identity
    FOREIGN KEY (tms_identity) REFERENCES tms_identities (tms_identity);

-- ------------------------------------------------------------------------------------------------
-- Rename column tms_user_id to tms_identity for table user_hosts.
-- ------------------------------------------------------------------------------------------------
ALTER TABLE user_hosts RENAME COLUMN tms_user_id TO tms_identity;

-- ---------------------------------------
-- delegations table
-- ---------------------------------------
--Add column tms_identity and add foreign key
--TODO: For upgrade, what about existing records? empty string? allow null?
-- Automatically insert <tacc_username>@danger_mode_idp for the tms_identity
ALTER TABLE delegations ADD COLUMN IF NOT EXISTS tms_identity TEXT NOT NULL DEFAULT 'dangerUser@dangerModeIdP'
    REFERENCES tms_identities(tms_identity) ON UPDATE CASCADE ON DELETE CASCADE;

-- ------------------------------------------------------------------------------------------------
-- Rename column client_user_id to rp_account for delegations, pubkeys and reservations.
-- ------------------------------------------------------------------------------------------------
ALTER TABLE delegations RENAME COLUMN client_user_id TO rp_account;
ALTER TABLE pubkeys RENAME COLUMN client_user_id TO rp_account;
ALTER TABLE reservations RENAME COLUMN client_user_id TO rp_account;
