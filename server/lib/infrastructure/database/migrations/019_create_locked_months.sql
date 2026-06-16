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

-- @description: Tracks months that have been locked, preventing any further
--               edits to transactions whose date falls within that month.
-- @param: none

CREATE TABLE locked_months (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id  TEXT        NOT NULL,
  month_year TEXT        NOT NULL, -- YYYY-MM format
  locked_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (entity_id, month_year)
);

CREATE INDEX locked_months_entity_idx ON locked_months (entity_id);
