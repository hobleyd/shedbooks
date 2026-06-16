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

-- Add sort_order column to bank_accounts for user-defined display ordering.
-- @param none
ALTER TABLE bank_accounts
  ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0;

-- Seed existing rows with their current alphabetical position per entity
-- so the initial order matches what users already see.
UPDATE bank_accounts
SET sort_order = sub.rn - 1
FROM (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY entity_id
           ORDER BY bank_name ASC, account_name ASC
         ) AS rn
  FROM bank_accounts
) sub
WHERE bank_accounts.id = sub.id;
