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

-- Migration: 027_add_system_accounts
-- Adds is_system flag to bank_accounts, extends account_type to include 'cash',
-- and enforces at most one system Cash account per entity via a partial unique index.
--
-- System accounts are created automatically by the server; they cannot be
-- edited or deleted by users.

ALTER TABLE bank_accounts ADD COLUMN is_system BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE bank_accounts DROP CONSTRAINT bank_accounts_account_type_check;
ALTER TABLE bank_accounts ADD CONSTRAINT bank_accounts_account_type_check
  CHECK (account_type IN ('transaction', 'savings', 'term_deposit', 'cash'));

CREATE UNIQUE INDEX idx_bank_accounts_system_cash_per_entity
  ON bank_accounts (entity_id)
  WHERE is_system = TRUE AND account_type = 'cash' AND deleted_at IS NULL;
