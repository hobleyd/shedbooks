-- @description Creates the bank_accounts table for storing entity bank account details.
-- @param entity_id TEXT - The entity (tenant) identifier.
-- @param bank_name TEXT - Financial institution name.
-- @param account_name TEXT - Name the account is held in.
-- @param bsb CHAR(6) - Bank State Branch code, 6 digits, no dash.
-- @param account_number TEXT - Account number, 6–10 digits.
-- @param account_type TEXT - One of: transaction, savings, term_deposit.
-- @param currency CHAR(3) - ISO 4217 currency code, default AUD.

CREATE TABLE bank_accounts (
  id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id      TEXT        NOT NULL,
  bank_name      TEXT        NOT NULL,
  account_name   TEXT        NOT NULL,
  bsb            CHAR(6)     NOT NULL,
  account_number TEXT        NOT NULL,
  account_type   TEXT        NOT NULL
                             CHECK (account_type IN ('transaction', 'savings', 'term_deposit')),
  currency       CHAR(3)     NOT NULL DEFAULT 'AUD',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at     TIMESTAMPTZ
);

CREATE INDEX idx_bank_accounts_entity
  ON bank_accounts (entity_id)
  WHERE deleted_at IS NULL;
