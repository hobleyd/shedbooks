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

-- @description Creates the entity_details table for storing organisation identity information.
-- @param entity_id TEXT - The entity (tenant) identifier from Auth0 app_metadata.
-- @param name TEXT - The organisation name.
-- @param abn CHAR(11) - The 11-digit Australian Business Number.
-- @param incorporation_identifier TEXT - The incorporation or association registration number.

CREATE TABLE entity_details (
  entity_id                TEXT        PRIMARY KEY,
  name                     TEXT        NOT NULL,
  abn                      CHAR(11)    NOT NULL,
  incorporation_identifier TEXT        NOT NULL,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
