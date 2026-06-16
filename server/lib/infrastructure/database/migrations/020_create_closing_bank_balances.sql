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

-- 020_create_closing_bank_balances.sql
-- Records the closing bank balance for a specific bank account at the end
-- of each reconciliation period. Upserted on (entity_id, bank_account_id,
-- balance_date) so re-running a reconciliation overwrites the prior record.

-- @param id               Unique record identifier
-- @param entity_id        Organisation scope (Auth0 org id)
-- @param bank_account_id  FK to bank_accounts
-- @param balance_date     Last day of the statement period (ISO date)
-- @param balance_cents    Closing balance in cents (positive = credit)
-- @param statement_period Human-readable period string from the PDF statement
-- @param created_at       Timestamp of last upsert

CREATE TABLE IF NOT EXISTS closing_bank_balances (
  id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id        TEXT        NOT NULL,
  bank_account_id  UUID        NOT NULL REFERENCES bank_accounts(id),
  balance_date     DATE        NOT NULL,
  balance_cents    BIGINT      NOT NULL,
  statement_period TEXT        NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE (entity_id, bank_account_id, balance_date)
);
