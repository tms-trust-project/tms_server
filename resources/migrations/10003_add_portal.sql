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
--
-- Insert hard-coded types
-- TODO Might be able to create globus and tacc_tapis as part of a seeding step, but dander_mode
--      should probably always be created here for migration from TMS 0.3.
INSERT INTO identity_provider_types (provider_type) VALUES ('globus');
INSERT INTO identity_provider_types (provider_type) VALUES ('tacc_tapis');
INSERT INTO identity_provider_types (provider_type) VALUES ('danger_mode');

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

--
-- Create identity_provider to be used as resource provider for existing MVP legacy "danger mode" records.
INSERT INTO identity_providers (id, name, client_id, client_secret, identity_redirect_url, oauth2_token_url,
                                provider_type, supports_login, supports_resources)
VALUES ('danger_mode_idp', 'DangerMode IdP', '12345678-1234-1234-1234-dangermode123', 'DangerModezf9afuG9RzpE6DCDvkrM',
        'https://auth.danger.dummy.org/v2/oauth2/authorize', 'https://auth.danger.dummy.org/v2/oauth2/token',
        'danger_mode', true, false);

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

-- TODO For existing MVP legacy "donger mode" records created for TMS 0.3 and earlier, we need to
--      add TMS identities for every record in the user_mfa, delegations and user_hosts table.
-- TODO Select all distinct client_user_id records from user_mfa and delegations and for each create a new
--   tms_identity record in tms_identities.
--

--  Create a TMS identity with a special name to act as a potential fallback for MVP legacy danger mode records.
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
-- TODO/TBD Is the empty string OK for rp_account?
ALTER TABLE resource_provider_logins ADD COLUMN IF NOT EXISTS rp_account TEXT NOT NULL DEFAULT '';
ALTER TABLE resource_provider_logins ADD COLUMN IF NOT EXISTS rp_id NOT NULL DEFAULT 'danger_mode';
ALTER TABLE resource_provider_logins ADD COLUMN IF NOT EXISTS last_login TIMESTAMPTZ NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc');

ALTER TABLE resource_provider_logins ADD CONSTRAINT identity_uuid_account_key UNIQUE (tms_identity, rp_id, rp_account);
ALTER TABLE resource_provider_logins ADD CONSTRAINT fk_rp_id FOREIGN KEY (rp_id) REFERENCES identity_providers(id);

-- ------------------------------------------------------------------------------------------------
-- Rename column tms_user_id to tms_identity for table user_hosts.
-- ------------------------------------------------------------------------------------------------
ALTER TABLE user_hosts RENAME COLUMN tms_user_id TO tms_identity;

-- ---------------------------------------
-- delegations table
-- ---------------------------------------
--TODO: For upgrade, what about existing records? empty string? allow null?
-- Automatically insert <tacc_username>@danger_mode_idp for the tms_identity
--Add column tms_identity with foreign key reference to tms_identities
-- NOTE: The hard coded string here must match the one used above for the tms_identities table.
ALTER TABLE delegations ADD COLUMN IF NOT EXISTS tms_identity TEXT NOT NULL DEFAULT 'dangerUser@dangerModeIdP'
    REFERENCES tms_identities(tms_identity) ON UPDATE CASCADE ON DELETE CASCADE;

-- ------------------------------------------------------------------------------------------------
-- Rename column client_user_id to rp_account for delegations, pubkeys and reservations.
-- ------------------------------------------------------------------------------------------------
ALTER TABLE delegations RENAME COLUMN client_user_id TO rp_account;
ALTER TABLE pubkeys RENAME COLUMN client_user_id TO rp_account;
ALTER TABLE reservations RENAME COLUMN client_user_id TO rp_account;

-- ------------------------------------------------------------------------------------------------
-- Add foreign keys for tms_identity referencing tms_identities table for tables
--    resource_provider_logins, delegations, user_hosts
-- Each tms_identity in each table must represent an identity in the tms_identities table.
-- NOTE: For delegations this is done above when adding the new column to the table.
-- As also mentioned above, this is needed because for delegations and the other tables we want to make sure we always
-- reference a unique tms_identity. If all tables reference this as a Foreign Key this will ensure that tms_identity
-- columns all reference the same unique identity unique within TMS
-- ------------------------------------------------------------------------------------------------
ALTER TABLE resource_provider_logins ADD CONSTRAINT fk_tms_identity
    FOREIGN KEY (tms_identity) REFERENCES tms_identities (tms_identity);
ALTER TABLE user_hosts ADD CONSTRAINT fk_tms_identity
    FOREIGN KEY (tms_identity) REFERENCES tms_identities (tms_identity);


