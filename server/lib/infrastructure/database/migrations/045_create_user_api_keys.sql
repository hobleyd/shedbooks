-- Migration 045: Create user_api_keys table
--
-- Stores per-user API keys (as SHA-256 hashes) for authenticating CardDAV
-- clients that cannot use JWT Bearer tokens (e.g. iOS Contacts).
--
-- @param entity_id  The Auth0 organisation ID scoping the key
-- @param user_id    The Auth0 sub claim of the key owner
-- @param user_email The email of the key owner at the time of generation
-- @param api_key_hash  SHA-256 hex digest of the raw API key (never stored plain)
-- @param created_at Timestamp of last generation (refreshed on regenerate)

CREATE TABLE user_api_keys (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    entity_id    VARCHAR     NOT NULL,
    user_id      VARCHAR     NOT NULL,
    user_email   VARCHAR     NOT NULL,
    api_key_hash VARCHAR(64) NOT NULL,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_user_api_keys_entity_user UNIQUE (entity_id, user_id)
);

CREATE UNIQUE INDEX idx_user_api_keys_hash ON user_api_keys (api_key_hash);
