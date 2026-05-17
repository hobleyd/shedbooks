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
