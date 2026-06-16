-- Copyright (C) 2026 David Hobley
--
-- This file is part of Shedbooks.
--
-- Shedbooks is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- Shedbooks is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with Shedbooks. If not, see <https://www.gnu.org/licenses/>.

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
