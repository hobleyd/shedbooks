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

-- @description: Adds bank_account_id to locked_months so each bank account's
--               period can be locked independently. Existing locks are removed
--               because they cannot be associated with a specific bank account.
-- @param: none

DELETE FROM locked_months;

ALTER TABLE locked_months
  ADD COLUMN bank_account_id UUID NOT NULL;

ALTER TABLE locked_months
  DROP CONSTRAINT locked_months_entity_id_month_year_key;

ALTER TABLE locked_months
  ADD CONSTRAINT locked_months_entity_account_month_unique
    UNIQUE (entity_id, bank_account_id, month_year);

ALTER TABLE locked_months
  ADD CONSTRAINT fk_locked_months_bank_account
    FOREIGN KEY (bank_account_id) REFERENCES bank_accounts(id) ON DELETE CASCADE;

CREATE INDEX locked_months_bank_account_idx ON locked_months (bank_account_id);
