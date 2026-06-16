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

-- Infer parent_id for GL accounts from label hierarchy.
-- e.g. label "4-2000-60" becomes a child of "4-2000" which is a child of "4".
-- The direct parent is the longest label that is a strict prefix (label || '-') of this account's label.
UPDATE general_ledger g
SET parent_id = (
  SELECT g2.id
  FROM general_ledger g2
  WHERE g2.entity_id = g.entity_id
    AND g2.deleted_at IS NULL
    AND g2.id != g.id
    AND g.label LIKE g2.label || '-%'
  ORDER BY length(g2.label) DESC
  LIMIT 1
)
WHERE g.deleted_at IS NULL;
