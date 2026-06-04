-- Creates the user_presence table to track the most recent activity
-- of each authenticated user per entity.
--
-- @column entity_id  Auth0 organisation ID
-- @column user_id    Auth0 user sub claim (unique user identifier)
-- @column user_email Email from JWT; may be empty for service accounts
-- @column role       Highest role held at last activity (viewer, contributor, administrator)
-- @column last_seen  UTC timestamp of most recent authenticated request
-- @column ip_address Client IP derived from reverse-proxy headers at last access
CREATE TABLE user_presence (
  entity_id   TEXT         NOT NULL,
  user_id     TEXT         NOT NULL,
  user_email  TEXT         NOT NULL DEFAULT '',
  role        TEXT         NOT NULL DEFAULT 'viewer',
  last_seen   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  ip_address  TEXT         NOT NULL DEFAULT '',
  PRIMARY KEY (entity_id, user_id)
);
