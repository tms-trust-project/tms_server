-- Save the tokens from logging in to a resource provider.
-- They will be used for further interactions with the RP service.
ALTER TABLE resource_provider_logins
ADD COLUMN IF NOT EXISTS rp_token TEXT;

ALTER TABLE resource_provider_logins
ADD COLUMN IF NOT EXISTS rp_token_refresh TEXT;