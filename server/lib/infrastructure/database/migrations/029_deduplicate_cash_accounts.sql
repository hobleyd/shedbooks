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

-- Deduplicate cash accounts created before the system-account feature existed.
--
-- Step 1: Where no system cash account exists yet, promote the manual one to system.
-- Step 2: Soft-delete any remaining non-system cash accounts (now superseded).

UPDATE bank_accounts
SET is_system  = TRUE,
    updated_at = NOW()
WHERE account_type = 'cash'
  AND is_system    = FALSE
  AND deleted_at  IS NULL
  AND NOT EXISTS (
    SELECT 1
    FROM   bank_accounts b2
    WHERE  b2.entity_id    = bank_accounts.entity_id
      AND  b2.account_type = 'cash'
      AND  b2.is_system    = TRUE
      AND  b2.deleted_at  IS NULL
  );

UPDATE bank_accounts
SET deleted_at = NOW(),
    updated_at = NOW()
WHERE account_type = 'cash'
  AND is_system    = FALSE
  AND deleted_at  IS NULL;
