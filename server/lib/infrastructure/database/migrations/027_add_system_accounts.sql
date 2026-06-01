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
