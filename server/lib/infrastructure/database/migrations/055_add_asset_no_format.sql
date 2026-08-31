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

-- Migration: 055_add_asset_no_format
-- Adds a configurable Asset No format to entity_details (same pattern as
-- invoice_number_format), and fixes historical Nursery asset numbers that
-- were minted with the letter P instead of N (the section is named
-- "Nursery"; P appears to be a leftover from an earlier naming scheme).
-- Only rows whose asset_type is exactly 'Nursery' are touched, so any
-- unrelated section that happens to start with P elsewhere is unaffected.
--
-- The rename is guarded by NOT EXISTS so it can never trip the
-- assets_entity_asset_no_unique constraint: if an entity already has an
-- unrelated asset_no that happens to collide with the renamed value (e.g. a
-- different N-lettered section using the same year/number), that one row is
-- left as-is rather than failing the whole migration (and blocking server
-- startup, since this file runs inside a single transaction).

-- @param asset_no_format Format pattern for generating sequential asset numbers.
--                          Tokens: YYYY (4-digit year), YY (2-digit year),
--                          {S} (first letter of the selected Section), # (sequential digit).
--                          Defaults to 'YYYY-{S}-####' producing numbers like 2026-N-0001.
ALTER TABLE entity_details ADD COLUMN IF NOT EXISTS asset_no_format TEXT NOT NULL DEFAULT 'YYYY-{S}-####';

UPDATE assets a
SET asset_no = regexp_replace(a.asset_no, '-P-', '-N-'),
    updated_at = NOW()
WHERE a.asset_type = 'Nursery'
  AND a.asset_no ~ '-P-'
  AND NOT EXISTS (
    SELECT 1 FROM assets b
    WHERE b.entity_id = a.entity_id
      AND b.asset_no = regexp_replace(a.asset_no, '-P-', '-N-')
  );
