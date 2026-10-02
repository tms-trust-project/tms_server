-- Resources available in a Resource Provider.
CREATE TABLE
    IF NOT EXISTS resources (
        id SERIAL PRIMARY KEY,
        resource_local_id TEXT NOT NULL,
        name TEXT NOT NULL,
        url TEXT NOT NULL,
        description TEXT,
        rp_id TEXT NOT NULL REFERENCES identity_providers (id),
        created TIMESTAMPTZ NOT NULL DEFAULT (NOW () AT TIME ZONE 'utc'),
        updated TIMESTAMPTZ NOT NULL DEFAULT (NOW () AT TIME ZONE 'utc'),
        UNIQUE (rp_id, resource_id)
    );

ALTER TABLE resources OWNER TO tms;

-- This table establishes the username in a resource for a RP identity.
CREATE TABLE
    IF NOT EXISTS usernames (
        id SERIAL PRIMARY KEY,
        resource_id INTEGER REFERENCES resources (id),
        resource_provider_login_id INTEGER REFERENCES resource_provider_logins (id),
        username TEXT NOT NULL,
        created TIMESTAMPTZ NOT NULL DEFAULT (NOW () AT TIME ZONE 'utc'),
        updated TIMESTAMPTZ NOT NULL DEFAULT (NOW () AT TIME ZONE 'utc')
    );

ALTER TABLE usernames OWNER TO tms;