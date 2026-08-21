--
-- Add tables used by TMS portal backend
-- This includes all the tables as of 21 Aug 2026
--    with portal clients table renamed to prtl_clients
-- Note that portal resource_provider_account_logins table is intended to serve the same purpose as
--      the server user_mfa table

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

CREATE TABLE IF NOT EXISTS identity_provider_types
(
    provider_type TEXT PRIMARY KEY            NOT NULL,
    created               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc')
    );

INSERT INTO identity_provider_types (provider_type)
VALUES ('globus');
INSERT INTO identity_provider_types (provider_type)
VALUES ('tacc_tapis');

ALTER TABLE identity_providers
    ADD CONSTRAINT fk_provider FOREIGN KEY (provider_type) REFERENCES identity_provider_types (provider_type);

CREATE TABLE IF NOT EXISTS keys
(
    kid             TEXT PRIMARY KEY            NOT NULL,
    jwt_public_key  TEXT                        NOT NULL,
    jwt_private_key TEXT                        NOT NULL,
    created               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc')
    );

CREATE TABLE IF NOT EXISTS prtl_clients
(
    id      TEXT PRIMARY KEY            NOT NULL,
    name    TEXT                        NOT NULL,
    secret  TEXT                        NOT NULL,
    created               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc')
    );

CREATE TABLE IF NOT EXISTS configuration
(
    config_name  TEXT PRIMARY KEY            NOT NULL,
    config_value JSONB                       NOT NULL,
    created               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc')
    );

CREATE TABLE IF NOT EXISTS allowed_redirects
(
    uri       TEXT                        NOT NULL,
    client_id TEXT                        NOT NULL,
    created               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated               TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    constraint fk_client_id FOREIGN KEY (client_id) REFERENCES prtl_clients (id)
    );

-- ---------------------------------------
-- user_mfa table
-- ---------------------------------------
-- This table records when a user's MFA validation will expire.
-- CREATE TABLE IF NOT EXISTS user_mfa
-- changed name because it's not really user_mfa.  I don't have strong feelings about what we call it though.
CREATE TABLE IF NOT EXISTS resource_provider_account_logins
(
    id                          SERIAL PRIMARY KEY,
    tms_identity                 TEXT NOT NULL,
    resource_provider_account   TEXT NOT NULL,
    resource_provider_uuid      UUID NOT NULL,
    last_login                  TIMESTAMPTZ NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    enabled                     BOOLEAN NOT NULL,
    created                     TIMESTAMPTZ NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated                     TIMESTAMPTZ NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    UNIQUE (tms_identity, resource_provider_uuid, resource_provider_account),
    FOREIGN KEY(resource_provider_uuid) REFERENCES identity_providers(uuid)
    );

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
    FOREIGN KEY(client_id) REFERENCES prtl_clients(id)
    );

CREATE TABLE IF NOT EXISTS issued_tokens
(
    access_token  TEXT PRIMARY KEY  NOT NULL,
    expiration    TIMESTAMPTZ       NOT NULL,
    revoked       BOOLEAN           NOT NULL DEFAULT false,
    created       TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc'),
    updated       TIMESTAMPTZ       NOT NULL DEFAULT (NOW() AT TIME ZONE 'utc')
    );
