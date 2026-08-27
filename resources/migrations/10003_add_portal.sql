-- ================================================================================================
-- Add tables needed for TMS Portal backend. TMS portal and server will use the same DB
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

-- All cloud and resource IdPs
-- Example cloud IdPs: UT Austin, UC San Diego, Univ of Pittsburgh, ACCESS
-- Example resource providers: TACC, SDSC, PSC
CREATE TABLE IF NOT EXISTS identity_providers
(
    uuid                  UUID PRIMARY KEY  NOT NULL DEFAULT gen_random_uuid(),
    id                    TEXT              NOT NULL,
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
    updated               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    UNIQUE (id)
);
ALTER TABLE identity_providers OWNER TO tms;
ALTER TABLE identity_providers
    ADD CONSTRAINT fk_provider FOREIGN KEY (provider_type) REFERENCES identity_provider_types (provider_type);

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
DO $$
BEGIN
  IF EXISTS(SELECT * FROM information_schema.columns WHERE table_name='clients' and column_name='app_name')
  THEN
ALTER TABLE clients RENAME COLUMN app_name TO name;
END IF;
END $$;
-- ------------------------------------------------------------------------------------------------
-- Rename column client_secret to secret. This is simpler and matches what the portal code is using.
-- NOTE: TODO Keep column client_id as is because TMS server already has a column 'id' as a SERIAL primary key
-- ------------------------------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS(SELECT * FROM information_schema.columns WHERE table_name='clients' and column_name='client_secret')
  THEN
    ALTER TABLE clients RENAME COLUMN client_secret TO secret;
  END IF;
END $$;

-- ================================================================================================
-- Rename table user_mfa to resource_provider_logins to better reflect the purpose.
--   This table records the last time the user logged into their resource provider account.
-- ================================================================================================
ALTER TABLE IF EXISTS user_mfa RENAME TO resource_provider_logins;
-- ------------------------------------------------------------------------------------------------
-- Rename column tms_user_id to tms_identity.
-- ------------------------------------------------------------------------------------------------
DO $$
BEGIN
  IF EXISTS(SELECT * FROM information_schema.columns WHERE table_name='resource_provider_logins' and column_name='tms_user_id')
  THEN
    ALTER TABLE resource_provider_logins RENAME COLUMN tms_user_id TO tms_identity;
  END IF;
END $$;

-- ================================================================================================
-- Add columns and constraints to resource_provider_logins table
-- ================================================================================================
ALTER TABLE resource_provider_logins ADD COLUMN IF NOT EXISTS provider_account TEXT NOT NULL DEFAULT '';
ALTER TABLE resource_provider_logins ADD COLUMN IF NOT EXISTS provider_uuid UUID NOT NULL DEFAULT gen_random_uuid();
ALTER TABLE resource_provider_logins ADD COLUMN IF NOT EXISTS last_login TIMESTAMPTZ NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc');

ALTER TABLE resource_provider_logins ADD CONSTRAINT identity_uuid_account_key
    UNIQUE (tms_identity, provider_uuid, provider_account);
ALTER TABLE resource_provider_logins ADD CONSTRAINT uuid_fkey FOREIGN KEY (provider_uuid) REFERENCES identity_providers(uuid);
