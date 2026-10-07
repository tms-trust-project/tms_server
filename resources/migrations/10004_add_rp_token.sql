-- Save the access and refresh tokens from logging in to a resource provider.
-- They will be used for further interactions with the RP service.
ALTER TABLE resource_provider_logins
ADD COLUMN IF NOT EXISTS rp_access_token TEXT;

ALTER TABLE resource_provider_logins
ADD COLUMN IF NOT EXISTS rp_refresh_token TEXT;